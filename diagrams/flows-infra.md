# Flows — Infrastructure & Network Diagram (single canonical file)

This single file contains both the infrastructure layout (Azure VNet/Subnet/NSG) and the application/data/control flows for the project. It replaces previous diagram variants and is the canonical diagram to render.

```mermaid
%%{init: {"theme":"neutral", "flowchart": {"nodeSpacing":20, "rankSpacing":28}} }%%
flowchart TB

  %% --- Admin / Orchestration
  subgraph AdminLayer["Admin / Orchestration"]
    direction TB
    Admin[Administrator]
    TF[Terraform]
    CI[CI Pipeline]
  end

  %% --- Application Layer
  subgraph App["Application Layer"]
    direction TB
    FE[Browser / Frontend]
    Backend[Backend FastAPI]
    Tools[cis-tool.sh and scripts]
  end

  %% --- Azure Network / Cassandra Cluster
  subgraph Azure["Azure - Virtual Network 10.0.0.0/16"]
    direction TB
    subgraph Subnet["Subnet: 10.0.1.0/24 (Cassandra cluster)"]
      direction LR
      Bastion[Bastion / Jump Host<br>10.0.1.10<br>Public IP: 4.194.10.192]
      DB1[DB1 - Seed<br>10.0.1.11]
      DB2[DB2 - Data<br>10.0.1.12]
      DB3[DB3 - Data<br>10.0.1.13]
    end

    subgraph NSG["Network Security Group (NSG) - rules"]
      NSG22[SSH: 22 - Whitelisted only]
      NSG7000[Inter-node: 7000 - Internal only]
      NSG9042[Client: 9042 - Blocked by default]
    end
  end

  %% --- Flows / Connections
  Admin -->|terraform apply| TF
  CI -->|run pipeline| TF
  TF -->|provision| Bastion
  TF -->|provision| DB1
  TF -->|provision| DB2
  TF -->|provision| DB3

  FE -->|HTTP and WS| Backend
  Backend -->|SSH key via Bastion| Bastion
  Backend -->|CQL client 9042| DB1
  Backend -->|CQL client 9042| DB2
  Backend -->|CQL client 9042| DB3
  Backend -->|invoke audit scripts| Tools
  Tools -->|SCP and SSH run| Bastion

  Bastion -->|SSH relay| DB1
  Bastion -->|SSH relay| DB2
  Bastion -->|SSH relay| DB3

  %% Cassandra ring (bidirectional gossip)
  DB1 <--> DB2
  DB2 <--> DB3
  DB3 <--> DB1

  %% NSG visual links (dashed)
  NSG22 -.-> Bastion
  NSG7000 -.-> DB1
  NSG7000 -.-> DB2
  NSG7000 -.-> DB3
  NSG9042 -.-> DB1
  NSG9042 -.-> DB2
  NSG9042 -.-> DB3

  classDef infra fill:#f3f7ff,stroke:#2b5ca3,stroke-width:1px;
  class Bastion,DB1,DB2,DB3 infra;
```

Notes:

- This canonical diagram models both the physical Azure network and the application flows. Key points:
  - Terraform provisions Bastion and DB nodes directly; there is no abstract `VMs` node.
  - Bastion is a jump host (not a Cassandra master). Avoid calling it "master" to prevent confusion.
  - Cassandra nodes form a ring (bidirectional gossip) and listen on inter-node port 7000 (internal only).
  - Client port 9042 should be blocked by default at NSG unless explicitly allowed.

Rendering:

Use Mermaid CLI to render this file's mermaid block. From repo root:

```bash
npx @mermaid-js/mermaid-cli -i diagrams/flows-infra.md -o diagrams/flows-infra.png
```

If you prefer I can also export PNG/SVG here (I'll run mermaid-cli in the environment).
