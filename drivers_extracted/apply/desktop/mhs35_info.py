#!/usr/bin/env python3
# 小屏信息内容生成: 抓 getInfoCN.py 的第一个信息块 -> 用 /proc/stat 修正 CPU 使用率 -> 抓不到则用内置生成器
# 用法: python3 mhs35_info.py 输出文件 [getInfoCN.py 路径]
import sys, time, subprocess, socket, os, threading

def cpu_use(sec=0.4):
    def snap():
        with open("/proc/stat") as f:
            return list(map(int, f.readline().split()[1:8]))
    a = snap()
    time.sleep(sec)
    b = snap()
    d = [y - x for x, y in zip(a, b)]
    tot = sum(d)
    if tot <= 0:
        return 0.0
    return round(100.0 * (tot - d[3] - d[4]) / tot, 1)

def cpu_temp():
    try:
        r = subprocess.run(["vcgencmd", "measure_temp"], capture_output=True, timeout=3)
        return r.stdout.decode().strip().replace("temp=", "").replace("'C", "")
    except Exception:
        return "?"

def mem():
    d = {}
    with open("/proc/meminfo") as f:
        for ln in f:
            d[ln.split(":")[0]] = int(ln.split()[1])
    tot = d.get("MemTotal", 0) // 1024
    used = (d.get("MemTotal", 0) - d.get("MemAvailable", 0)) // 1024
    free = d.get("MemAvailable", 0) // 1024
    return tot, used, free

def disk():
    st = os.statvfs("/")
    total = st.f_blocks * st.f_frsize // (1024**3)
    used = (st.f_blocks - st.f_bfree) * st.f_frsize // (1024**3)
    pct = round(100.0 * used / total, 1) if total else 0
    return total, used, pct

def ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("192.168.1.1", 1))
        return s.getsockname()[0]
    except Exception:
        return "127.0.0.1"
    finally:
        s.close()

def fallback():
    t, u, f = mem()
    dt, du, dp = disk()
    lines = ["---------系统信息---------",
             "CPU 温度 = " + cpu_temp() + " ℃",
             "CPU 使用 = " + str(cpu_use()) + " %",
             "",
             "内存 总共有 = " + str(t) + " MB",
             "内存 已使用 = " + str(u) + " MB",
             "内存 空闲中 = " + str(f) + " MB",
             "",
             "磁盘 总共有 = " + str(dt) + " GB",
             "磁盘 已使用 = " + str(du) + " GB",
             "磁盘 百分比 = " + str(dp) + " %",
             "",
             "IP 地址 = " + ip(),
             "---------系统信息---------"]
    return "\n".join(lines) + "\n(用内置生成器)"

def capture_first_block(app, timeout_sec=6):
    # 应用是无限循环, 抓第一个信息块就终止, 每轮约1.5秒
    p = subprocess.Popen(["python3", "-u", app], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
    lines = []
    done = threading.Event()

    def watchdog():
        if not done.wait(timeout_sec):
            p.terminate()

    threading.Thread(target=watchdog, daemon=True).start()
    for line in p.stdout:
        s = line.rstrip("\n")
        if "\x1b" in s:
            continue
        lines.append(s)
        if len(lines) >= 3 and s.startswith("---------"):
            break
    done.set()
    p.terminate()
    return "\n".join(lines)

def main():
    out_path = sys.argv[1]
    app = sys.argv[2] if len(sys.argv) > 2 else ""
    text = ""
    if app:
        try:
            text = capture_first_block(app)
        except Exception:
            text = ""
    if not text.strip():
        text = fallback()
    else:
        v = cpu_use()
        lines = ["CPU 使用 = " + str(v) + " %" if "CPU 使用" in ln else ln for ln in text.split("\n")]
        text = "\n".join(lines)
    open(out_path, "w", encoding="utf-8").write(text.rstrip() + "\n")

if __name__ == "__main__":
    main()

