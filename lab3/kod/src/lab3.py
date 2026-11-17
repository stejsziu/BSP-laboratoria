"""
Port of wykresy.m  (analog accelerometer/gyro calibration + free-motion plots)
plus the new digital IMU (imu_gr2_bsp_1..3.txt).

Plots are exported as PDF pages that are exactly the size of the figure
(no A4 page) to  <script dir>/../raport/wykresy/

Requires: numpy, pandas, matplotlib   (pip install numpy pandas matplotlib)
"""
from pathlib import Path

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

# --------------------------------------------------------------------------- #
# SETTINGS
# --------------------------------------------------------------------------- #
BASE = Path(__file__).resolve().parent        # kod/src
DATA_DIR = BASE.parent / "data"             # kod/data  (txt files)
OUT_DIR = BASE.parent / "raport" / "wykresy"  # ./../raport/wykresy

G = 9.81

# analog sensor - calibration files (LabVIEW, one per rotation axis)
CAL_FILES = {
    "x": "Gr2_gx-osx.txt",
    "y": "Gr2_gx-osy.txt",
    "z": "Gr2_gx-osz.txt",
}
# analog sensor - free motion file (same LabVIEW format). Not provided yet:
# put the file name here and the analog plots will be generated too.
ANALOG_FREE_FILE = None                     # e.g. "Gr2_dowolny.txt"

# digital IMU - free motion files (accel [g], gyro [deg/s])
IMU_FILES = ["imu_gr2_bsp_1.txt", "imu_gr2_bsp_2.txt", "imu_gr2_bsp_3.txt"]

# plot look (same as in the .m)
WIDTH_CM, HEIGHT_CM = 15, 8
FS_MIN, FS_MID, FS_BIG = 12, 13, 15
LW = 1.25
GRID_COLOR, GRID_ALPHA = (0.5, 0.5, 0.5), 0.3
COL_A = ["#2F4B7C", "#2A9D8F", "#F4A261"]
COL_GIR = ["#6A4C93", "#8DA9C4", "#F28482"]


# --------------------------------------------------------------------------- #
# DATA LOADING
# --------------------------------------------------------------------------- #
def load_labview(path):
    """LabVIEW .txt: skip both headers (2nd '***End_of_Header***' + column
    names line). Returns array [t, ax, ay, az, wx, wy, wz]."""
    with open(path, encoding="latin-1") as f:
        lines = f.readlines()
    ends = [i for i, l in enumerate(lines) if "End_of_Header" in l]
    first = ends[-1] + 2                      # header line + 'X_Value ...' line
    return np.loadtxt(lines[first:], usecols=range(7))


def load_imu(path):
    """Tab separated, decimal comma, leading tab. -> [t, ax, ay, az, wx, wy, wz]"""
    df = pd.read_csv(path, sep="\t", header=None, decimal=",").dropna(axis=1, how="all")
    return df.to_numpy(dtype=float)


# --------------------------------------------------------------------------- #
# ACCELEROMETER CALIBRATION  (findchangepts + kmeans in the .m)
# --------------------------------------------------------------------------- #
def changepoints_mean(x, n_changes=6):
    """Greedy binary segmentation (mean statistic) - like findchangepts(...,
    'Statistic','mean','MaxNumChanges',n). Returns sorted split indices."""
    x = np.asarray(x, float)
    cs, cs2 = np.r_[0, np.cumsum(x)], np.r_[0, np.cumsum(x ** 2)]

    def sse(a, b):                            # residual error of x[a:b]
        n = b - a
        s = cs[b] - cs[a]
        return (cs2[b] - cs2[a]) - s * s / n

    def best_split(a, b):
        if b - a < 2:
            return None, 0.0
        k = np.arange(a + 1, b)
        nl, nr = k - a, b - k
        sl, sr = cs[k] - cs[a], cs[b] - cs[k]
        gain = sse(a, b) - ((cs2[k] - cs2[a]) - sl ** 2 / nl) - ((cs2[b] - cs2[k]) - sr ** 2 / nr)
        j = int(np.argmax(gain))
        return int(k[j]), float(gain[j])

    segs = [(0, len(x))]
    splits = []
    cache = {segs[0]: best_split(*segs[0])}
    for _ in range(n_changes):
        seg = max(segs, key=lambda s: cache[s][1])
        k = cache[seg][0]
        if k is None:
            break
        segs.remove(seg)
        for new in ((seg[0], k), (k, seg[1])):
            segs.append(new)
            cache[new] = best_split(*new)
        splits.append(k)
    return sorted(splits)


def kmeans_1d(v, k=3, iters=100):
    """Tiny deterministic 1-D k-means (centres initialised min..max)."""
    v = np.asarray(v, float)
    c = np.linspace(v.min(), v.max(), k)
    for _ in range(iters):
        lab = np.argmin(np.abs(v[:, None] - c[None, :]), axis=1)
        new = np.array([v[lab == i].mean() if np.any(lab == i) else c[i] for i in range(k)])
        if np.allclose(new, c):
            break
        c = new
    return c


def alfa_from_channel(x):
    """Sensitivity [V/(m/s^2)] of one accel axis from one 'flip' channel."""
    idx = [0] + changepoints_mean(x, 6) + [len(x)]
    means = [np.mean(x[idx[k]:idx[k + 1] + 1]) for k in range(len(idx) - 1)]
    centers = kmeans_1d(means, 3)
    return (centers.max() - centers.min()) / (2 * G)


def calibrate_accel(cal):
    """cal[axis] = array [t, ax, ay, az, wx, wy, wz] of rotation about that axis."""
    ax, ay, az = (cal[k][:, 1:4] for k in "xyz")
    alfa_yx = alfa_from_channel(ay[:, 0])     # x-accel seen in the y-rotation file
    alfa_zx = alfa_from_channel(az[:, 0])
    alfa_xy = alfa_from_channel(ax[:, 1])
    alfa_zy = alfa_from_channel(az[:, 1])
    alfa_xz = alfa_from_channel(ax[:, 2])
    alfa_yz = alfa_from_channel(ay[:, 2])
    alfa = np.array([(alfa_yx + alfa_zx) / 2,
                     (alfa_xy + alfa_zy) / 2,
                     (alfa_yz + alfa_xz) / 2])
    bias = np.array([ax[:, 0].mean(), ay[:, 1].mean(), az[:, 2].mean()])
    return alfa, bias


# --------------------------------------------------------------------------- #
# GYRO CALIBRATION  (hand-picked time windows in the .m -> auto-detected here)
# --------------------------------------------------------------------------- #
def find_pulses(t, U, n_pulses=4, pad=0.1, merge_gap=0.2):
    """Find the n rotation pulses in a gyro voltage signal.
    Returns U0 (rest level) and list of (start_idx, end_idx)."""
    U0 = np.median(U)
    dev = np.abs(U - U0)
    quiet = dev < 0.5 * dev.max() * 0.1
    sigma = np.std(U[quiet])
    thr = max(10 * sigma, 0.05)
    U0 = np.mean(U[dev < thr])                # rest level without the pulses

    active = np.flatnonzero(np.abs(U - U0) > thr)
    groups, start, prev = [], active[0], active[0]
    for i in active[1:]:
        if t[i] - t[prev] > merge_gap:
            groups.append((start, prev))
            start = i
        prev = i
    groups.append((start, prev))
    groups = [g for g in groups if g[1] - g[0] > 5]       # drop noise spikes
    # keep the n biggest pulses (by integrated area), restore time order
    area = [abs(np.trapezoid(U[a:b + 1] - U0, t[a:b + 1])) for a, b in groups]
    keep = sorted(np.argsort(area)[::-1][:n_pulses])
    groups = [groups[i] for i in keep]
    if len(groups) != n_pulses:
        print(f"  ! warning: found {len(groups)} pulses instead of {n_pulses}")
    dt = np.median(np.diff(t))
    p = int(round(pad / dt))
    return U0, [(max(a - p, 0), min(b + p, len(t) - 1)) for a, b in groups]


def calibrate_gyro(cal):
    """Returns rest levels U0[3] [V] and sensitivities kw[3] [deg/(V*s)]."""
    U0s, kws = [], []
    for ax_i, name in enumerate("xyz"):
        d = cal[name]
        t, U = d[:, 0], d[:, 4 + ax_i]
        U0, pulses = find_pulses(t, U)
        integ = [np.trapezoid(U[a:b + 1] - U0, t[a:b + 1]) for a, b in pulses]
        kw = np.mean(90.0 / np.array(integ))
        print(f"  gyro {name}: U0 = {U0:.4f} V, pulses at "
              + ", ".join(f"{t[a]:.2f}-{t[b]:.2f}s" for a, b in pulses)
              + f"  ->  kw = {kw:.2f} deg/(V s)")
        U0s.append(U0)
        kws.append(kw)
    return np.array(U0s), np.array(kws)


# --------------------------------------------------------------------------- #
# ATTITUDE: kinematic equations and quaternions
# --------------------------------------------------------------------------- #
def euler_kinematic(w, dt):
    """w: (N,3) [deg/s] -> phi, theta, psi [deg] integrating Euler kinematics."""
    N = len(w)
    ang = np.zeros((N, 3))
    for i in range(N - 1):
        phi, theta = ang[i, 0], ang[i, 1]
        sp, cp = np.sin(np.radians(phi)), np.cos(np.radians(phi))
        tt, ct = np.tan(np.radians(theta)), np.cos(np.radians(theta))
        T = np.array([[1, sp * tt, cp * tt],
                      [0, cp, -sp],
                      [0, sp / ct, cp / ct]])
        ang[i + 1] = ang[i] + (T @ w[i]) * dt
    return ang[:, 0], ang[:, 1], ang[:, 2]


def quaternion_attitude(w, dt):
    """w: (N,3) [deg/s] -> phi, theta, psi [deg] (unwrapped phi and psi)."""
    N = len(w)
    qa = np.array([1.0, 0, 0, 0])             # phi0 = theta0 = psi0 = 0
    phik, thetak, psik = np.zeros(N), np.zeros(N), np.zeros(N)
    for i in range(1, N):
        wn = np.linalg.norm(w[i])
        th = np.radians(wn * dt)
        if wn > 0:
            qb = np.r_[np.cos(th / 2), np.sin(th / 2) * w[i] / wn]
        else:
            qb = np.array([1.0, 0, 0, 0])
        a0, a1, a2, a3 = qa
        b0, b1, b2, b3 = qb
        q = np.array([a0 * b0 - a1 * b1 - a2 * b2 - a3 * b3,
                      a0 * b1 + a1 * b0 + a2 * b3 - a3 * b2,
                      a0 * b2 - a1 * b3 + a2 * b0 + a3 * b1,
                      a0 * b3 + a1 * b2 - a2 * b1 + a3 * b0])
        q /= np.linalg.norm(q)
        q0, q1, q2, q3 = q
        thetak[i] = np.degrees(np.arcsin(np.clip(-2 * (q1 * q3 - q0 * q2), -1, 1)))
        phik[i] = np.degrees(np.arctan2(2 * (q2 * q3 + q0 * q1), 1 - 2 * (q1 ** 2 + q2 ** 2)))
        psik[i] = np.degrees(np.arctan2(2 * (q1 * q2 + q0 * q3), 1 - 2 * (q2 ** 2 + q3 ** 2)))
        qa = q
    return (np.degrees(np.unwrap(np.radians(phik))), thetak,
            np.degrees(np.unwrap(np.radians(psik))))


# --------------------------------------------------------------------------- #
# PLOTTING
# --------------------------------------------------------------------------- #
def save_plot(t, series, colors, labels, title, subtitle, ylabel, fname, legend_loc="upper right"):
    fig, ax = plt.subplots(figsize=(WIDTH_CM / 2.54, HEIGHT_CM / 2.54),
                           layout="constrained")
    for y, c, lab in zip(series, colors, labels):
        ax.plot(t, y, lw=LW, color=c, label=lab)
    fig.suptitle(title, fontsize=FS_BIG, fontweight="bold")
    ax.set_title(subtitle, fontsize=FS_MID)
    ax.set_xlabel("time [s]", fontsize=FS_MIN)
    ax.set_ylabel(ylabel, fontsize=FS_MIN)
    ax.tick_params(labelsize=FS_MIN)
    ax.set_xlim(t.min() - 1, t.max() + 1)
    ax.grid(True, color=GRID_COLOR, alpha=GRID_ALPHA)
    ax.legend(loc=legend_loc, fontsize=FS_MIN)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    # page size == figure size (no A4, no extra margins)
    fig.savefig(OUT_DIR / f"{fname}.pdf")
    plt.close(fig)
    print("  saved", OUT_DIR / f"{fname}.pdf")


def plot_set(t, acc, gyr, dt, title, prefix, acc_unit, gyr_unit="deg/s",
             raw_acc=None, raw_gyr=None):
    """acc, gyr: (N,3) processed data. raw_*: optional (N,3) voltages."""
    la = [r"$a_x$", r"$a_y$", r"$a_z$"]
    lw_ = [r"$\omega_x$", r"$\omega_y$", r"$\omega_z$"]
    lang = [r"$\Phi$", r"$\Theta$", r"$\Psi$"]

    if raw_acc is not None:
        save_plot(t, raw_acc.T, COL_A, la, f"{title} - akcelerometry", "dane nieobrobione",
                  "voltage [V]", f"{prefix}przyspieszenia_surowe", "upper left")
        save_plot(t, raw_gyr.T, COL_GIR, lw_, f"{title} - giroskopy", "dane nieobrobione",
                  "voltage [V]", f"{prefix}giroskopy_surowe")

    save_plot(t, acc.T, COL_A, la, f"{title} - akcelerometry", "dane przetworzone",
              f"acceleration [{acc_unit}]", f"{prefix}przyspieszenia")
    save_plot(t, gyr.T, COL_GIR, lw_, f"{title} - giroskopy", "dane przetworzone",
              f"angular rate [{gyr_unit}]", f"{prefix}giroskopy")

    save_plot(t, euler_kinematic(gyr, dt), COL_GIR, lang, f"{title} - giroskopy",
              "r-nia kinematyki", "angle [deg]", f"{prefix}giroskopy_kinematyka")
    save_plot(t, quaternion_attitude(gyr, dt), COL_GIR, lang, f"{title} - giroskopy",
              "rachunek kwaternionowy", "angle [deg]", f"{prefix}giroskopy_kwaterniony")


# --------------------------------------------------------------------------- #
# MAIN
# --------------------------------------------------------------------------- #
def main():
    # ---------- analog sensor: calibration (+ free motion if available) ----
    cal = {k: load_labview(DATA_DIR / f) for k, f in CAL_FILES.items()}
    print("Analog sensor calibration")
    alfa, bias = calibrate_accel(cal)
    print(f"  accel alfa [V/(m/s^2)] = {alfa},  bias [V] = {bias}")
    U0, kw = calibrate_gyro(cal)

    if ANALOG_FREE_FILE:
        d = load_labview(DATA_DIR / ANALOG_FREE_FILE)
        t = d[:, 0]
        dt = np.median(np.diff(t))
        acc = (d[:, 1:4] - bias) / alfa
        gyr = (d[:, 4:7] - U0) * kw
        print("Analog sensor - free motion")
        plot_set(t, acc, gyr, dt, "Ruch dowolny", "analog_", "m/s^2",
                 raw_acc=d[:, 1:4], raw_gyr=d[:, 4:7])
    else:
        print("  (no analog free-motion file set -> analog plots skipped)")

    # ---------- digital IMU ------------------------------------------------
    for n, fname in enumerate(IMU_FILES, start=1):
        d = load_imu(DATA_DIR / fname)
        t = d[:, 0]
        dt = np.median(np.diff(t))
        acc = d[:, 1:4]                       # already in g
        gyr = d[:, 4:7]                       # already in deg/s
        gyr = gyr - gyr[:100].mean(axis=0)    # gyro zero-rate offset (sensor at rest)
        print(f"IMU {n}: {fname}  ({len(t)} samples, dt = {dt:.3f}s)")
        plot_set(t, acc, gyr, dt, f"IMU - pomiar {n}", f"imu{n}_", "g")


if __name__ == "__main__":
    main()
