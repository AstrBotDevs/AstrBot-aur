# 架构

```bash
/
├── opt/
│   └── astrbot/                  # [只读] 应用程序核心代码库
│       ├── astrbot/              # Python 源码包
│       ├── scripts/              # 辅助脚本
│       ├── pyproject.toml        # 依赖定义文件 (uv 的权威来源)
│       └── config.template       # 实例配置文件模板 (由 PKGBUILD 安装)
│
├── usr/
│   ├── bin/
│   │   └── astrbotctl            # [核心入口] 管理脚本 (CRUD 实例、环境初始化)
│   │
│   └── lib/systemd/system/
│       └── astrbot@.service      # [服务模板] 支持 systemctl start astrbot@<instance>
│
├── etc/
│   └── astrbot/                  # [配置中心] 存放实例配置文件
│       ├── bot1.conf             # 实例 'bot1' 的配置 (端口、数据路径、额外参数)
│       └── bot2.conf             # 实例 'bot2' 的配置
│
├── var/
│   ├── lib/astrbot/              # [数据持久化] 存放实例的运行时数据
│   │   ├── bot1/                 # 实例 'bot1' 的数据 (数据库、日志、插件数据)
│   │   └── bot2/                 # 实例 'bot2' 的数据
│   │
│   └── cache/astrbot/            # [运行时环境] 存放 uv 创建的虚拟环境
│       ├── venv-bot1/            # 实例 'bot1' 的独立 Python 环境 (含依赖 + 插件)
│       └── venv-bot2/            # 实例 'bot2' 的独立 Python 环境
│
└── home/user/                    # 用户目录 (完全解耦，不依赖特定用户)
```
