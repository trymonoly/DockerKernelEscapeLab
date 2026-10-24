# DockerKernelEscapeLab

用于 Docker/Linux 容器逃逸研究的**无损攻击面审计与复现前置条件检查环境**。仓库覆盖容器运行时漏洞、已有公开容器逃逸研究的内核漏洞，以及需要特定条件才可能用于逃逸的内核漏洞。

> **重要边界**：本项目不是一键逃逸 EXP 集合。Compose 不更换宿主机内核，也不部署旧版 runC/containerd；它只执行版本、Namespace、Capabilities、Seccomp、Socket、cgroup 和挂载关系检查，不触发漏洞、不覆盖文件、不修改页缓存。

## 为什么真实复现不能只靠 docker-compose.yaml

- **内核漏洞**：普通容器共享宿主机内核。Compose 无法给不同服务分配不同 Linux 内核；在真实宿主机触发漏洞可能导致宿主机提权、崩溃或文件破坏。
- **runC/containerd 漏洞**：runC 和 containerd 是宿主机组件。把旧版二进制放进普通容器，不等于让宿主机实际使用旧版运行时。
- **逃逸结论**：容器内 root、容器内 setuid 提权、接口可达和宿主机逃逸是不同结果，不能混为一谈。

因此，本仓库把 **Compose 无损探测** 与 **真实漏洞复现** 分开。真实复现只能使用一次性虚拟机、独立内核/运行时、快照、无生产网络和无敏感数据的环境；不要在工作机、云生产宿主机或共享集群直接实验。

## 覆盖范围

| 分类 | CVE |
|---|---|
| 容器运行时漏洞 | CVE-2019-5736、CVE-2024-21626、CVE-2021-30465、CVE-2020-15257 |
| 已有明确容器逃逸研究的内核漏洞 | CVE-2022-0185、CVE-2021-22555、CVE-2022-0492、CVE-2020-14386 |
| 特定条件下可用于逃逸的内核漏洞 | CVE-2024-1086、CVE-2023-32233、CVE-2022-25636、CVE-2023-0386、CVE-2016-5195、CVE-2022-0847 |
| 页缓存破坏/跨容器原语 | CVE-2026-31431（Copy Fail） |

## 环境要求

- Linux 宿主机；Windows/macOS 应使用 Linux 虚拟机，不能把 Docker Desktop 的 Linux VM 当成生产宿主机做逃逸实验。
- Docker Engine 与 Docker Compose v2。
- 仅用于自己拥有或获得明确授权的环境。

## 快速开始：每个 CVE 独立启动

每个 `cves/<CVE-ID>/compose.yaml` 只定义一个 `audit` 服务，可单独构建、启动和删除，不依赖根目录聚合 Compose。

从仓库根目录选择 CVE：

```bash
CVE=CVE-2026-31431
docker compose -f "cves/$CVE/compose.yaml" run --build --rm audit
```

例如只启动 Copy Fail 审计：

```bash
docker compose -f cves/CVE-2026-31431/compose.yaml run --build --rm audit
```

保存该 CVE 的笔记输出：

```bash
mkdir -p audit-output
docker compose -f "cves/$CVE/compose.yaml" run --build --rm audit | tee "audit-output/$CVE.txt"
```

Netfilter 环境只增加容器内的 `NET_ADMIN`，AF_PACKET 环境只增加 `NET_RAW`，并使用 Compose internal network；其余普通审计环境不增加 Capability。

### 独立环境索引

| 分类 | CVE 目录 |
|---|---|
| 运行时 | [CVE-2019-5736](cves/CVE-2019-5736/)、[CVE-2024-21626](cves/CVE-2024-21626/)、[CVE-2021-30465](cves/CVE-2021-30465/)、[CVE-2020-15257](cves/CVE-2020-15257/) |
| 明确逃逸研究 | [CVE-2022-0185](cves/CVE-2022-0185/)、[CVE-2021-22555](cves/CVE-2021-22555/)、[CVE-2022-0492](cves/CVE-2022-0492/)、[CVE-2020-14386](cves/CVE-2020-14386/) |
| 条件性内核漏洞 | [CVE-2024-1086](cves/CVE-2024-1086/)、[CVE-2023-32233](cves/CVE-2023-32233/)、[CVE-2022-25636](cves/CVE-2022-25636/)、[CVE-2023-0386](cves/CVE-2023-0386/)、[CVE-2016-5195](cves/CVE-2016-5195/)、[CVE-2022-0847](cves/CVE-2022-0847/) |
| 页缓存破坏 | [CVE-2026-31431](cves/CVE-2026-31431/) |

### containerd-shim 可见性检查

CVE-2020-15257 需要宿主机网络命名空间。以下命令会加入宿主机网络，**只在隔离虚拟机中执行**：

```bash
docker compose -f cves/CVE-2020-15257/compose.yaml run --build --rm audit
```

该服务仍然是非 root、只读并移除全部 Capabilities，只读取 `/proc/net/unix`，不会连接或调用 shim API。

## 通用探测字段

| 输出 | 含义 | 不能据此得出的结论 |
|---|---|---|
| `USERNS_CREATE=OK` | 可以创建用户命名空间 | 不代表内核存在漏洞 |
| `USERNETNS_CREATE=OK` | 可以创建用户和网络命名空间 | 不代表 nf_tables 一定可利用 |
| `NFT_RULESET_READ=OK` | 当前网络命名空间允许只读查询规则 | 不代表可以完成内核提权 |
| `AF_PACKET_SOCKET=OK` | AF_PACKET 攻击面可达 | 不代表宿主机未修复 |
| `AF_ALG_SOCKET=OK` | 可以创建 AF_ALG Socket | 不代表 AEAD/`authencesn` 路径可利用 |
| `AEAD_BIND=OK` | 测试用 AEAD 算法可绑定 | 不代表 Copy Fail 一定存在 |
| `CONTAINERD_SHIM_SOCKET=VISIBLE` | 当前网络命名空间能看到 shim Socket | 仍需确认 containerd 版本和配置 |
| `Seccomp: 2` | 已启用 Seccomp 过滤 | 不知道具体系统调用是否被拦截 |
| `CGROUP_FS=cgroup2fs` | 主要使用 cgroup v2 | CVE-2022-0492 的 cgroup v1 路径通常不适用 |

`EPERM`/`Operation not permitted` 通常表示安全策略或权限阻断；`ENOENT` 只表示测试对象不存在；模块名未出现在 `/proc/modules` 中也不能排除功能已编译进内核或尚未加载。

## 宿主机版本检查

以下命令是**宿主机命令**，不是容器内命令：

```bash
uname -a
cat /etc/os-release
runc --version
containerd --version
docker version
```

容器内的 `/etc/os-release` 属于镜像，不能用于判断宿主机补丁状态。发行版可能向后移植安全修复，因此必须同时核对发行版 CVE 公告和已安装软件包版本。

---

# 一、容器运行时漏洞

## CVE-2019-5736 — runC 容器逃逸

- **影响**：runC ≤ 1.0-rc6；Docker < 18.09.2。
- **类型**：文件描述符与 `/proc/self/exe` 处理缺陷。
- **利用方式**：恶意镜像或受控容器覆盖宿主机 runC 二进制，下次调用 runC 时执行攻击者代码。
- **容器内探测**：无法可靠确认；容器中的 `/usr/bin/runc` 不是宿主机 runC。必须在宿主机检查 `runc --version` 和 `docker version`。
- **预期返回**：runC ≤ 1.0-rc6 表示版本初筛命中；更高版本仍应结合发行版补丁公告。Compose 审计不会输出宿主机 runC 版本。
- **防御**：升级 runC 至 1.0-rc7 以上、Docker 至 18.09.2 以上，不运行不可信镜像。

## CVE-2024-21626 — runC 文件描述符泄漏逃逸

- **影响**：runC 1.0.0-rc93 至 1.1.11。
- **类型**：内部文件描述符泄漏与工作目录校验不足。
- **利用方式**：恶意镜像或容器进程利用泄漏的宿主机文件描述符，使新进程访问宿主机文件系统。
- **容器内探测**：无法只凭当前容器可靠确认；宿主机执行 `runc --version`，并检查镜像/OCI `process.cwd` 和管理员 `runc exec --cwd` 场景。
- **预期返回**：runC ≤ 1.1.11 且处于受影响范围表示需要升级；普通 `docker version` 不能替代对实际 runC 二进制的检查。
- **防御**：升级 runC 至 1.1.12 以上，并更新 Docker/containerd 中捆绑的 runC。

## CVE-2021-30465 — runC 挂载路径竞态逃逸

- **影响**：runC ≤ 1.0.0-rc94。
- **类型**：挂载目标符号链接与挂载操作之间的竞态条件。
- **利用方式**：在检查与挂载之间交换符号链接，使挂载落到非预期路径或暴露宿主机文件。
- **容器内探测**：普通容器无法确认 runC 修复状态；需要宿主机版本信息，并确认是否允许不可信用户控制镜像、OCI mounts 或卷配置。
- **预期返回**：runC ≤ 1.0.0-rc94 为受影响版本初筛；容器内存在符号链接本身不是漏洞证据。
- **防御**：升级 runC 至 1.0.0-rc95 以上，限制不可信用户创建容器和配置挂载的权限。

## CVE-2020-15257 — containerd-shim API 暴露逃逸

- **影响**：containerd < 1.3.9，以及 1.4.0–1.4.2。
- **类型**：抽象 Unix Socket 访问控制不当。
- **利用方式**：宿主机网络命名空间中的容器访问 containerd-shim API，请求 shim 创建进程。
- **容器内探测**：在隔离 VM 中运行 `docker compose -f cves/CVE-2020-15257/compose.yaml run --build --rm audit`；宿主机同时检查 `containerd --version`。
- **预期返回**：`CONTAINERD_SHIM_SOCKET=VISIBLE` 表示接口可见；`NOT_VISIBLE` 表示当前命名空间未发现。只有旧版 containerd、host network 和 Socket 可见等条件同时满足才具有实际意义。
- **防御**：升级 containerd 至 1.3.9、1.4.3 或更高版本，避免不必要的 `--network host`。

---

# 二、已有明确容器逃逸研究的内核漏洞

## CVE-2022-0185 — Filesystem Context 堆溢出

- **影响**：Linux 5.1 至 5.16.1 等未修复版本。
- **类型**：`legacy_parse_param` 堆缓冲区溢出。
- **利用方式**：通过文件系统配置接口触发堆溢出，构造内核读写或代码执行能力，再突破 Namespace；已有 kCTF 容器逃逸研究。
- **容器内探测**：`docker compose -f cves/CVE-2022-0185/compose.yaml run --build --rm audit`，关注 `KERNEL_RELEASE`、`USERNS_CREATE` 和 `Seccomp`；还需审计 `fsopen/fsconfig` 可达性。
- **预期返回**：`USERNS_CREATE=OK` 只表示可能能在用户命名空间获得 `CAP_SYS_ADMIN`；`FAIL` 通常表示该前提被阻断。两者都不能单独证明补丁状态。
- **防御**：升级宿主机内核，限制非特权用户命名空间及不必要的文件系统配置系统调用。

## CVE-2021-22555 — Netfilter 堆越界写

- **影响**：Linux 2.6.19 至 5.11.x 的多个未修复版本。
- **类型**：Netfilter 兼容模式处理中的堆越界写。
- **利用方式**：在用户和网络命名空间中取得 `CAP_NET_ADMIN`，触发越界写并取得内核权限；已有 Kubernetes Pod 逃逸研究。
- **容器内探测**：`docker compose -f cves/CVE-2021-22555/compose.yaml run --build --rm audit`，检查 `USERNETNS_CREATE`、`NFT_RULESET_READ` 和 Capabilities。
- **预期返回**：`USERNETNS_CREATE=OK` 或 `NFT_RULESET_READ=OK` 表示部分攻击面可达；`FAIL` 表示当前路径受限，但仍需结合宿主机配置。
- **防御**：升级内核，移除不必要的 `CAP_NET_ADMIN`，限制非特权用户命名空间。

## CVE-2022-0492 — cgroups v1 `release_agent` 权限校验缺陷

- **影响**：未修复的 Linux 内核，仅涉及 cgroups v1。
- **类型**：内核逻辑与权限校验不足。
- **利用方式**：宽松配置下的高权限容器挂载可写 cgroupfs，控制 `release_agent`，使内核在初始 Namespace 执行程序。
- **容器内探测**：`docker compose -f cves/CVE-2022-0492/compose.yaml run --build --rm audit`，检查 `CGROUP_FS`、cgroup 挂载选项、`CAP_SYS_ADMIN` 和挂载命名空间能力。
- **预期返回**：`CGROUP_FS=cgroup2fs` 表示该 cgroup v1 路径通常不适用；cgroup 挂载为 `ro` 且无法重新挂载会阻断利用。`tmpfs` 需要进一步检查，不能直接视为安全。
- **防御**：升级内核，优先使用 cgroups v2，保留 Seccomp/AppArmor/SELinux，移除 `CAP_SYS_ADMIN`。

## CVE-2020-14386 — AF_PACKET 内核内存破坏

- **影响**：Linux 4.6 至 5.8.x 等未修复版本。
- **类型**：AF_PACKET 数据包处理中的整数溢出与堆越界写。
- **利用方式**：利用 `CAP_NET_RAW` 创建相关套接字并触发内存破坏，取得宿主机内核权限。
- **容器内探测**：`docker compose -f cves/CVE-2020-14386/compose.yaml run --build --rm audit`，关注 `AF_PACKET_SOCKET` 和 `KERNEL_RELEASE`。
- **预期返回**：`AF_PACKET_SOCKET=OK` 表示攻击面可达，不代表漏洞存在；`FAIL errno=1` 通常表示权限或安全策略阻断。
- **防御**：升级内核，移除容器的 `CAP_NET_RAW`，限制不必要的 AF_PACKET Socket。

---

# 三、满足特定条件时可用于逃逸的内核漏洞

## CVE-2024-1086 — nf_tables 双重释放/UAF

- **影响**：Linux 5.14 至 6.6.14 等多个版本，以发行版公告为准。
- **类型**：nf_tables 判定数据处理中的双重释放。
- **利用方式**：通过 nf_tables 触发对象重复释放并构造内核读写能力；公开研究重点是本地提权，不应直接等同于通用 Docker 逃逸。
- **容器内探测**：`docker compose -f cves/CVE-2024-1086/compose.yaml run --build --rm audit`，检查用户/网络 Namespace 和 Netfilter 只读访问。
- **预期返回**：`USERNETNS_CREATE=OK`、`NFT_RULESET_READ=OK` 表示满足部分前提；最终必须核对宿主机补丁。
- **防御**：升级内核，限制非特权用户命名空间，使用 Seccomp/LSM 限制 Netfilter 操作。

## CVE-2023-32233 — nf_tables 匿名集合 UAF

- **影响**：Linux 6.3.1 及之前多个未修复版本。
- **类型**：nf_tables 匿名集合批处理中的释放后使用。
- **利用方式**：利用 nf_tables 批处理触发 UAF，进一步实现本地提权；容器中是否可用取决于 Namespace 和安全策略。
- **容器内探测**：`docker compose -f cves/CVE-2023-32233/compose.yaml run --build --rm audit`，检查 `USERNETNS_CREATE`、`NFT_RULESET_READ` 和 Seccomp。
- **预期返回**：只读查询成功说明接口可达，不证明匿名集合漏洞存在或能稳定利用。
- **防御**：升级内核，限制非特权用户命名空间及容器内 Netfilter 管理权限。

## CVE-2022-25636 — Netfilter `nf_dup_netdev` 堆越界写

- **影响**：Linux 5.4 至 5.16.10 等未修复版本。
- **类型**：Netfilter 网络设备转发处理中的堆越界写。
- **利用方式**：取得用户和网络命名空间中的 `CAP_NET_ADMIN`，通过 nf_tables 触发越界写。
- **容器内探测**：`docker compose -f cves/CVE-2022-25636/compose.yaml run --build --rm audit`，检查 `USERNETNS_CREATE`、`NFT_RULESET_READ` 和 `cap_net_admin`。
- **预期返回**：`cap_net_admin` 存在或 Namespace 创建成功只表示权限前提可能满足；不是漏洞确认。
- **防御**：升级内核，移除 `CAP_NET_ADMIN`，限制非特权用户命名空间。

## CVE-2023-0386 — OverlayFS 权限映射校验缺陷

- **影响**：Linux 6.2 及之前部分未修复版本。
- **类型**：OverlayFS 文件复制与 UID/GID 映射校验不当。
- **利用方式**：结合用户命名空间、OverlayFS 或 FUSE 构造特殊文件，使复制后的文件产生异常属主或权限。
- **容器内探测**：`docker compose -f cves/CVE-2023-0386/compose.yaml run --build --rm audit`，并手动执行 `unshare -Urnm true`；检查 `grep -E 'overlay|fuse' /proc/self/mountinfo`。
- **预期返回**：`unshare` 无输出且退出码为 0 表示相关 Namespace 可创建；根文件系统为 `overlay` 不足以证明可利用，还需相应挂载权限。
- **防御**：升级内核，限制非特权用户命名空间及不受信任的 OverlayFS/FUSE 挂载。

## CVE-2016-5195 — Dirty COW

- **影响**：Linux 2.6.22 至 4.8.2 等多个老版本。
- **类型**：写时复制机制中的竞态条件。
- **利用方式**：利用只读内存映射与 `/proc/self/mem` 之间的竞态修改只读文件内容。
- **容器内探测**：`docker compose -f cves/CVE-2016-5195/compose.yaml run --build --rm audit`，检查内核版本和 `findmnt`/挂载信息，寻找与宿主机或其他容器共享的文件。
- **预期返回**：发现 `READABLE_SETUID` 只表示容器内存在目标；修改容器私有文件不等于逃逸。不要使用实际写入来验证。
- **防御**：升级内核，避免向容器挂载宿主机敏感文件。

## CVE-2022-0847 — Dirty Pipe

- **影响**：Linux 5.8 起至修复前；常见修复版本包括 5.16.11、5.15.25、5.10.102。
- **类型**：管道缓冲区标志初始化错误与页缓存写入。
- **利用方式**：覆盖有读取权限的只读文件页缓存内容；只有能影响宿主机或其他工作负载共享文件时才可能形成逃逸。
- **容器内探测**：`docker compose -f cves/CVE-2022-0847/compose.yaml run --build --rm audit`，检查内核版本、可读文件和共享挂载关系。
- **预期返回**：只读文件或 `overlay` 根文件系统本身不是可利用证据；需要共享文件及容器外执行等后续条件。
- **防御**：升级内核，避免共享宿主机敏感文件，使用只读挂载并限制关键文件访问。

---

# 四、页缓存破坏与跨容器原语

## CVE-2026-31431 — Copy Fail

- **影响**：2017 年相关问题代码引入后至 2026 年修复前的多个 Linux 内核版本；具体状态以发行版公告为准。
- **类型**：`algif_aead` 加密接口逻辑缺陷、越界写与页缓存破坏。
- **利用方式**：低权限本地进程通过 AF_ALG、`splice()` 等路径向可读文件页缓存写入受控数据；破坏 setuid 程序可提权。共享页缓存场景下可能构成跨容器/逃逸原语，但不等于默认 Docker 必然直接逃逸。
- **容器内探测**：`docker compose -f cves/CVE-2026-31431/compose.yaml run --build --rm audit`，检查 `AF_ALG_SOCKET`、`AEAD_BIND`、相关模块提示、setuid 文件和挂载关系。
- **预期返回**：见下表；接口成功只代表攻击面可达。主线修复提交为 `a664bf3d603d`，最终必须核对宿主机发行版补丁。
- **防御**：升级宿主机内核；对不可信容器通过 Seccomp 阻止 AF_ALG；临时禁用 `algif_aead` 前必须评估依赖 AF_ALG 的业务。

| 返回 | 初步解释 |
|---|---|
| `AF_ALG_SOCKET=OK`、`AEAD_BIND=OK` | AF_ALG AEAD 攻击面可达；不能据此判定漏洞存在 |
| `FAIL errno=1 (Operation not permitted)` | 当前路径可能被 Seccomp/LSM/权限策略阻断 |
| `AF_ALG_SOCKET=FAIL errno=97` | AF_ALG 地址族可能不受支持 |
| `AF_ALG_SOCKET=OK`、`AEAD_BIND=FAIL errno=2` | 测试用 `gcm(aes)` 不存在；不能排除 `authencesn` 风险 |
| `COPY_FAIL_MODULE_HINT=NOT_VISIBLE` | 不能排除；模块可能未加载或功能已内建 |
| 仅发现容器私有 setuid 文件 | 可能只影响容器内提权，不能证明宿主机逃逸 |

## 安全发布说明

发布到 GitHub 前请确认：

1. 仓库不包含真实宿主机信息、IP、Token、云凭证或内部镜像地址。
2. 不上传漏洞利用后生成的宿主机文件、内存转储或敏感数据。
3. 不把 `privileged: true`、Docker Socket 挂载、`CAP_SYS_ADMIN` 或宿主机根目录挂载加入 Compose。
4. 如果后续增加真实复现材料，应放在独立、明确标记的隔离 VM 项目中，并提供恢复快照和不影响宿主机的验证方法。

## 参考资料

- [NVD：CVE-2026-31431](https://nvd.nist.gov/vuln/detail/CVE-2026-31431)
- [Copy Fail 研究方说明](https://copy.fail/)
- [Red Hat：CVE-2026-31431](https://access.redhat.com/security/cve/CVE-2026-31431)
- [CVE-2022-0185 原始容器逃逸研究](https://www.willsroot.io/2022/01/cve-2022-0185.html)
- [CVE-2021-22555 原始 Kubernetes 逃逸研究](https://google.github.io/security-research/pocs/linux/cve-2021-22555/writeup.html)
- [CVE-2022-0492 Unit 42 分析](https://unit42.paloaltonetworks.com/cve-2022-0492-cgroups/)
- [runC 官方 CVE-2024-21626 公告](https://github.com/opencontainers/runc/security/advisories/GHSA-xr7r-f8xq-vfvv)
- [CVE-2024-1086 原始研究](https://pwning.tech/nftables/)
