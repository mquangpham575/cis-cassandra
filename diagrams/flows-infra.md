# Flows — Infrastructure & Application Interaction

This diagram shows a basic model linking the Frontend, Backend, Tools, and Infra in this project.

```mermaid
%%{init: {'theme':'default', 'flowchart': {'nodeSpacing': 25, 'rankSpacing': 25}} }%%
flowchart LR
  subgraph User
    A[Browser Frontend]
  end

  subgraph Frontend
    FE[Frontend Vite React]
  end

  subgraph Backend
    BE[Backend FastAPI]
    Routers[routers]
    Services[services]
    Models[models.py]
    WS[Websockets]
  end

  subgraph Tools
    CLI[cis-tool.sh and scripts]
  end

  subgraph Infra
    TF[Terraform]
    VMs[Virtual Machines]
    KV[KeyVault]
    NSG[Network Security Group]
    subgraph CassandraCluster[Cassandra Cluster]
      direction LR
      Master[Master Node]
      N1[Node 1]
      N2[Node 2]
      N3[Node 3]
    end
  end

  A --> FE
  FE -->|REST WebSocket| BE
  BE --> Routers
  Routers --> Services
  Services -->|SSH command| VMs
  Services -->|Cassandra client| Cassandra
  Services -->|invoke scripts| CLI
  Services --> WS
  CLI -->|provisioning| TF
  TF --> VMs
  VMs --> Master
  Master --> N1
  Master --> N2
  Master --> N3
  N1 --> N2
  N2 --> N3
  KV -->|secrets| BE
  NSG -->|network rules| VMs
  BE -->|generate reports| Reports[reports]

  classDef infra fill:#f9f,stroke:#333,stroke-width:1px;
  class TF,VMs,KV,Cassandra,NSG infra;
```

Notes:

- Frontend communicates with the Backend via REST and WebSocket (see `websockets/` and `frontend/src`).
- Backend routes live in `backend/routers` and call concrete logic in `backend/services` which interact with infra (SSH, Cassandra driver).
- Tools/scripts live in `scripts/` and `demo/bin`; they can be invoked by the backend or run manually for remediation or provisioning.
- Terraform definitions are in `/terraform` and provision the VMs, KeyVault, and network resources used by the backend and Cassandra nodes.

Next: add a short README and export diagram to PNG if you want a visual asset.
