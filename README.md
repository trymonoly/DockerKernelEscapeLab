# DockerKernelEscapeLab

按 CVE 独立组织的容器安全复现实验。每个目录使用 **Vagrant 隔离 VM + Docker Compose victim 容器**：VM 提供指定内核或 runC/containerd，容器提供模拟已攻陷的初始 Shell。仓库不放置自定义探测脚本或一键 EXP，手工命令和公开 PoC 来源写在各目录 README 中。

> 只能在自己拥有或明确授权的隔离环境使用。禁止在办公机、生产宿主机或共享集群直接替换内核/runC/containerd，禁止把复现命令用于未授权目标。

## 为什么是 VM + Compose

普通 Compose 容器共享宿主机内核，不能构造独立的漏洞内核；把旧 runC 放进容器也不会改变宿主机实际运行时。因此，本项目的复现边界是：

```text
每 CVE 一个一次性 VM
├── 指定 Linux 内核或 runC/containerd
├── Docker / Compose
└── victim 容器
    └── 容器内 Shell：手工探测与复现
```

`compose.yaml` 只负责 victim 容器。真实漏洞组件由同目录 `Vagrantfile` 安装。各 README 会明确结果是**宿主机逃逸、容器内本地提权，还是仅文件/页缓存原语**，不把这些结果混为一谈。

## 环境要求

- Windows/Linux/macOS 上的 Vagrant 与 VirtualBox（或按目录说明调整的 provider）。
- 足够磁盘和内存；不要同时启动全部 VM。
- 首次 provision 需要下载软件包；部分目录会从 kernel.org 编译 vanilla 内核，可能需要数十分钟及较多磁盘。完成后应断开 VM 的外部网络，再进行漏洞测试。
- 当前仓库配置在本机仅做静态校验；未声称所有环境已在本地实际跑通。

## 统一使用方法

进入一个 CVE 目录，例如：

```bash
cd cves/CVE-2024-1086
```

创建 VM：

```bash
vagrant up
```

如果该目录 README 说明安装了新内核，需要重启进入指定内核：

```bash
vagrant reload
```

保存干净快照并进入 VM：

```bash
vagrant snapshot save clean
vagrant ssh
```

在 **VM 内**启动 victim 容器（Compose v2 示例）：

```bash
cd /vagrant
docker compose up -d
docker compose exec victim bash
```

部分历史运行时环境安装的是 Compose v1，对应命令为 `docker-compose`；部分内核环境禁用 synced folder，并把 Compose 安装到 `/opt/lab`；CVE-2021-30465 使用 Kubernetes YAML 而不是 Compose。上述命令只是通用示例，始终以该目录 README 为准。

后续只按照该 CVE 的 README 执行手工命令。注意区分命令执行位置：`物理机`、`VM 宿主机` 和 `victim 容器` 并不相同。

恢复或删除环境：

```bash
vagrant snapshot restore clean
vagrant destroy -f
```

## 独立环境索引

| 分类 | CVE 目录 | 公开研究主要结果 |
|---|---|---|
| 运行时 | [CVE-2019-5736](cves/CVE-2019-5736/) | runC 宿主机逃逸 |
| 运行时 | [CVE-2024-21626](cves/CVE-2024-21626/) | runC 宿主机逃逸 |
| 运行时 | [CVE-2021-30465](cves/CVE-2021-30465/) | runC 挂载竞态与越界挂载 |
| 运行时 | [CVE-2020-15257](cves/CVE-2020-15257/) | host-network 容器访问 shim API |
| 内核 | [CVE-2022-0185](cves/CVE-2022-0185/) | kCTF 专用逃逸代码；Ubuntu FUSE 版是 LPE |
| 内核 | [CVE-2021-22555](cves/CVE-2021-22555/) | 公开源码包含 Kubernetes Pod 逃逸阶段 |
| 内核 | [CVE-2022-0492](cves/CVE-2022-0492/) | 宽松配置下的 cgroups v1 逃逸 |
| 内核 | [CVE-2020-14386](cves/CVE-2020-14386/) | 公开 reproducer 为内核崩溃/DoS，不是完整逃逸 |
| 内核 | [CVE-2024-1086](cves/CVE-2024-1086/) | 公开 PoC 以本地提权为主 |
| 内核 | [CVE-2023-32233](cves/CVE-2023-32233/) | 公开 PoC 以本地提权为主，强绑定内核 |
| 内核 | [CVE-2022-25636](cves/CVE-2022-25636/) | 公开 PoC 以本地提权为主，强绑定内核 |
| 内核 | [CVE-2023-0386](cves/CVE-2023-0386/) | 容器内 LPE；不能直接视为宿主机逃逸 |
| 页缓存/COW | [CVE-2016-5195](cves/CVE-2016-5195/) | vDSO 路线已有 Docker 逃逸验证，需宿主执行触发 |
| 页缓存 | [CVE-2022-0847](cves/CVE-2022-0847/) | Datadog 已有 Kubernetes 逃逸验证，需 runc/exec 条件 |
| 页缓存 | [CVE-2026-31431](cves/CVE-2026-31431/) | 已有 Pod-to-host 验证；不是默认 Docker 独立逃逸 |

## 每个目录包含什么

```text
cves/<CVE-ID>/
├── Vagrantfile   # 独立 VM 和漏洞组件版本
├── compose.yaml  # victim 容器及其实际权限前提
├── pod.yaml      # 仅需要 Kubernetes CRI 的目录提供
└── README.md     # 启动、手工探测、公开 PoC、预期结果、恢复和来源
```

具体文件以目录为准；CVE-2021-30465 等 Kubernetes 场景不使用 Compose 冒充复现。仓库不再包含 `audit.sh`、`af_alg_probe.py` 或运行一次就退出的 `audit` 服务。

## 验证状态说明

- **上游已验证**：公开研究者声明在指定版本上测试成功，不代表本项目已独立复现。
- **静态校验通过**：Vagrantfile/Compose 语法和安全边界检查通过，不代表漏洞触发成功。
- **本地已复现**：只有在实际启动 VM 并记录结果后才能使用；当前不得默认这样标注。

内核 PoC 常绑定精确 ABI、符号偏移、内核配置和 CPU 调度条件。即使 CVE 影响另一个版本，也不代表同一个 PoC 能在该版本直接运行。
