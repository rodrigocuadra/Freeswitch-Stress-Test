# 🚀 FreeSWITCH Stress Test Toolkit

Welcome to the **FreeSWITCH Stress Test Toolkit**, a practical utility designed to benchmark and evaluate FreeSWITCH performance under simulated high call loads. This project provides everything needed to:

- 🎯 Install FreeSWITCH from source
- 📊 Generate stress traffic to test server stability
- 🧾 Store CDRs (Call Detail Records) for later analysis

---

## 📦 Repository Contents

| File              | Description                                      |
|-------------------|--------------------------------------------------|
| `install_fs.sh`   | Script to install FreeSWITCH from source         |
| `stress_test.sh`  | Script to generate high call load                |
| `fs_cdr.sql`      | SQL schema to create the CDR table               |

---

## ⚙️ Prerequisites

- Two Linux servers (Debian 11/12 or compatible)
- Root SSH access
- Internet access from both servers
- Open ports for SIP communication (UDP 5060, 5080)

---

## 🧱 Step 1: Install FreeSWITCH on Both Servers

Run the following command **on both servers** to install FreeSWITCH from source:

```bash
wget https://raw.githubusercontent.com/rodrigocuadra/Freeswitch-Stress-Test/refs/heads/main/install_fs.sh
chmod +x install_fs.sh
./install_fs.sh
```

> ☑️ This will automatically download, compile, and install FreeSWITCH with standard SIP profiles.

---

## 📞 Step 2: Run the Stress Test

Once both servers are up and running with FreeSWITCH installed, log in to **one of the servers** (this will be your test controller), and run:

```bash
wget https://raw.githubusercontent.com/rodrigocuadra/Freeswitch-Stress-Test/refs/heads/main/stress_test.sh
chmod +x stress_test.sh
./stress_test.sh
```

During execution, the script will:

- Prompt for required network and performance parameters
- Automatically configure a gateway to the remote server
- Upload the destination dialplan to the remote server (for music-on-hold)
- Start launching calls incrementally to stress the system
- Monitor CPU, memory, network usage, and active calls
- Log results into `data.csv`

---

## 📁 Optional: Set Up CDR Storage

If you want to store detailed CDRs from your tests:

1. Create the database and table using `fs_cdr.sql` on your preferred SQL engine (PostgreSQL recommended).
2. Configure FreeSWITCH to log CDRs into the database using `mod_cdr_pg_csv` or `mod_odbc_cdr`.

---

## 📊 Results

After running the test, you'll get:

- **Live statistics** displayed step-by-step on screen
- A `data.csv` file containing all metrics for review
- A final summary of:
  - Max CPU usage
  - Max concurrent calls
  - Estimated calls per hour based on call duration

---

## 🧠 Notes

- Ensure the remote server allows unauthenticated SIP traffic (no registration required).
- This test uses `local_stream://moh` as the media source (Music on Hold).
- Modify the test script as needed to simulate different call durations, codecs, or SIP profiles.

---

## 👤 Author

**Rodrigo Cuadra**  
VitalPBX  
📧 [rcuadra@vitalpbx.com](mailto:rcuadra@vitalpbx.com)

---

## 🛡️ Disclaimer

This stress test is designed for **controlled lab environments**.  
**Do not run it in production** unless you know what you're doing.

Use responsibly.

---
