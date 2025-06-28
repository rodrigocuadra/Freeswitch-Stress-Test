# 🚀 FreeSWITCH Stress Test Toolkit

Welcome to the **FreeSWITCH Stress Test Toolkit**, a comprehensive framework to benchmark and analyze **FreeSWITCH's** SIP and media performance under stress. This utility helps VoIP engineers test scalability, stability, and resource usage in real-time scenarios.

Use this toolkit to:

* 🎯 Install FreeSWITCH from source
* 🔁 Launch simulated SIP calls
* 🧾 Store CDRs in PostgreSQL
* 📈 Monitor system usage (CPU, RAM, network, concurrency)

---

## 📦 Repository Contents

| File             | Description                                    |
| ---------------- | ---------------------------------------------- |
| `install_fs.sh`  | Installs FreeSWITCH and configures CDR storage |
| `stress_test.sh` | Launches SIP traffic for stress simulation     |
| `fs_cdr.sql`     | SQL schema for CDR logging                     |

---

## ⚙️ System Requirements

* Two Debian 12 servers (VMs or dedicated)
* Root access
* Outbound internet access (to pull media and install dependencies)
* Open UDP ports: 5060, 5080 for SIP / 10000–20000 for RTP
* Minimum: 2 vCPUs, 2 GB RAM

---

## 🛠️ Step 1: Install FreeSWITCH

Execute this on **both servers**:

```bash
wget https://raw.githubusercontent.com/rodrigocuadra/Freeswitch-Stress-Test/refs/heads/main/install_fs.sh
chmod +x install_fs.sh
./install_fs.sh
```

✅ The script performs:

* FreeSWITCH 1.10.12 compilation and installation
* SIP profile setup (internal/external)
* PostgreSQL database setup
* `fs_cdr.sql` execution for real-time CDR storage

---

## 📞 Step 2: Run the Stress Test

On the **controller server**, run:

**API (Optional)**
```bash
wget https://raw.githubusercontent.com/rodrigocuadra/Freeswitch-Stress-Test/refs/heads/main/install_stresstest_api.sh
chmod +x install_stresstest_api.sh
./install_stresstest_api.sh
```

**Stress Test**
```bash
wget https://raw.githubusercontent.com/rodrigocuadra/Freeswitch-Stress-Test/refs/heads/main/stress_test.sh
chmod +x stress_test.sh
./stress_test.sh
```

You’ll be prompted to:

* Input IPs of local and remote servers
* Choose test parameters (codecs, call duration, step size)

🧪 What the script does:

* Creates SIP gateway to the target server
* Uploads dialplan to play media via `local_stream://moh`
* Sends SIP calls in steps, monitors:

  * CPU usage
  * Load average
  * Bandwidth (TX/RX)
  * Concurrent channels
* Stores performance data in `data.csv`

---

## 📊 Example Results

A typical final report looks like:

* Max concurrent calls: **1600**
* Max CPU usage: **82.00%**
* Load average: **2.08**
* Avg bandwidth per call: **75.56 kb/s**
* Est. throughput: **36,000 calls/hour**

### 📷 Benchmark Snapshot:

![FreeSWITCH Stress Test Result](https://github.com/rodrigocuadra/Freeswitch-Stress-Test/blob/main/FreeswitchXML_2Core.png)

---

## 🔍 Interpretation

* The benchmark was conducted on a **Hyper-V virtual machine** with 2 vCPU cores and 3.8 GiB RAM.
* **CPU usage above 45%** is not recommended in production.
* The stress test simulates **two-way media calls** with audio playback on both sides.
* Bandwidth usage is nearly constant due to static MOH streaming.

---

## ⚙️ Customization Tips

* SIP profiles used are `internal.xml` and `external.xml`
* Media is sourced using `local_stream://moh`
* You can modify codecs, RTP range, and call length directly in the script
* PostgreSQL is used for call logging (can be extended for billing)

---

## 📤 CSV Output Sample

The script writes to `data.csv` with fields:

```
Step,Concurrent_Calls,CPU_Usage,Load_Avg,TX_kbps,RX_kbps
```

You can use this data to generate graphs, analyze system limits, or evaluate infrastructure upgrades.

---

## 👤 Author

**Rodrigo Cuadra**
VitalPBX
📧 [rcuadra@vitalpbx.com](mailto:rcuadra@vitalpbx.com)

---

## 🛡️ Disclaimer

⚠️ This is a **stress testing framework for lab use only**.
Do **not run in production** unless under supervision and with network isolation.

Use responsibly.

---

## 📎 Related Projects

* [Asterisk Stress Test Toolkit](https://github.com/rodrigocuadra/Asterisk-Stress-Test)

---

Happy benchmarking! 🎧📶
