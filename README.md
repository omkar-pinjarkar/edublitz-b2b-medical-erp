# EduBlitz Medical B2B ERP System

A production-grade **Medical Domain B2B ERP** for hospitals, distributors, and administrators. The stack is **three Spring Boot microservices**, a **React (Vite)** SPA, and **MongoDB** (Atlas or self-hosted).

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        CloudFront CDN                           │
│                    (React Frontend via S3)                      │
└──────────────────────────┬──────────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────────┐
│              AWS ALB Ingress Controller (EKS)                   │
└──────┬─────────────────────┬──────────────────────┬────────────┘
       │                     │                      │
┌──────▼──────┐    ┌─────────▼────────┐   ┌────────▼────────┐
│ user-service│    │ product-service  │   │  order-service  │
│  Port: 8081 │    │   Port: 8082     │   │   Port: 8083    │
│             │    │                  │   │                 │
│ Auth / JWT  │    │ Catalog / Stock  │   │ Order lifecycle │
│ Roles/Orgs  │    │ Batches / Reserve│   │ (+ product API) │
└──────┬──────┘    └─────────┬────────┘   └────────┬────────┘
       │                     │                      │
┌──────▼─────────────────────▼──────────────────────▼─────────────┐
│                     MongoDB Atlas (or local)                    │
│   users_db          products_db            orders_db            │
└──────────────────────────────────────────────────────────────────┘
```

## Tech Stack

| Layer        | Technology                                      |
|--------------|-------------------------------------------------|
| Frontend     | React 18 + Vite + TailwindCSS + TanStack Query  |
| Backend      | Spring Boot 3.x (3 microservices)               |
| Database     | MongoDB (Atlas recommended)                     |
| Auth         | JWT (HMAC-SHA256 / HS256), shared secret        |
| Cloud        | AWS (EKS, S3, CloudFront, Route53) — optional   |
| IaC          | Terraform (modular)                             |
| CI/CD        | Jenkins (see `jenkins/`)                        |
| Containers   | Docker + Kubernetes manifests in `k8s/`         |
| API Docs     | Swagger / OpenAPI 3.0 per service               |

## Domain Highlights

- **Catalog**: Active products only appear in hospital/distributor listings; soft-deleted products free their **SKU** for reuse.
- **Inventory**: Stock is tracked per **product + warehouse + batch** (`POST /products/inventory`). **Available** (sellable) = stored quantity minus reserved.
- **Orders**: Hospitals place orders; **distributors** (or admins) **approve** only when enough sellable stock exists — approval calls product-service to **reserve** stock (multi-batch allocation). Distributors only act on orders assigned to their **organization ID**.
- **Admin UI**: Organization **MongoDB IDs** are listed under **Organizations** for integration and user registration.

## Services

| Service         | Port | Responsibilities |
|-----------------|------|------------------|
| user-service    | 8081 | Auth, JWT, users, organizations, audit hooks |
| product-service | 8082 | Products, inventory batches, reserve/release APIs |
| order-service   | 8083 | Orders; calls product-service over HTTP with forwarded JWT |

## Roles

| Role        | Access |
|-------------|--------|
| ADMIN       | Organizations, all products/inventory (scoped APIs), all orders |
| DISTRIBUTOR | Own catalog & stock batches, incoming orders for own org |
| HOSPITAL    | Browse catalog, create/track own org’s orders |

## Project Structure

```
├── frontend/           # React + Vite (HashRouter for static hosting)
├── user-service/
├── product-service/
├── order-service/
├── docker/
├── k8s/
├── terraform/
├── jenkins/
└── docs/               # Deployment & architecture guides
```

## Documentation

| Document | Description |
|----------|-------------|
| [docs/README.md](docs/README.md) | Index of all guides |
| [docs/MANUAL_DEPLOYMENT.md](docs/MANUAL_DEPLOYMENT.md) | Run locally without Docker |
| [docs/DOCKER_DEPLOYMENT.md](docs/DOCKER_DEPLOYMENT.md) | Docker Compose + Atlas |
| [docs/KUBERNETES_DEPLOYMENT.md](docs/KUBERNETES_DEPLOYMENT.md) | EKS + AWS Load Balancer Controller |
| [k8s/README.md](k8s/README.md) | `kubectl apply` order |
| [docs/TERRAFORM_DEPLOYMENT.md](docs/TERRAFORM_DEPLOYMENT.md) | AWS infrastructure |
| [terraform/README.md](terraform/README.md) | Terraform modules |
| [docs/JENKINS_DEPLOYMENT.md](docs/JENKINS_DEPLOYMENT.md) | CI/CD pipelines |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Service boundaries & data flows |

## Quick Start

1. **Local:** [docs/MANUAL_DEPLOYMENT.md](docs/MANUAL_DEPLOYMENT.md) — HashRouter URLs like `http://localhost:5173/#/login`.
2. **Docker Compose:** [docs/DOCKER_DEPLOYMENT.md](docs/DOCKER_DEPLOYMENT.md) — APIs only; Atlas via `docker/.env`; frontend elsewhere (e.g. S3 + CloudFront).
3. **Kubernetes:** [docs/KUBERNETES_DEPLOYMENT.md](docs/KUBERNETES_DEPLOYMENT.md) + [k8s/README.md](k8s/README.md).
4. **Terraform:** [docs/TERRAFORM_DEPLOYMENT.md](docs/TERRAFORM_DEPLOYMENT.md).

## Prerequisites

| Tool | Notes |
|------|--------|
| **JDK 17** | Use for **running** services. Set `JAVA_HOME` to JDK 17 before **`mvn`** if your default JDK is newer (avoids Lombok/compiler issues). |
| Maven 3.9+ | `mvn clean package` per service |
| Node.js 18+ | Frontend |
| MongoDB | Local or Atlas; set **`MONGODB_URI`** (see each `.env.example`) |
| Docker | Optional (Compose) |

## Configuration

- **`application.yml`** defaults use **local MongoDB** (`mongodb://127.0.0.1:27017/...`). Set **`MONGODB_URI`** for Atlas.
- Copy **`.env.example` → `.env`** per service (gitignored). Load env before `java -jar`, e.g. `set -a && source .env && set +a` — see [MANUAL_DEPLOYMENT.md](docs/MANUAL_DEPLOYMENT.md).
- **Same `JWT_SECRET`** on user-, product-, and order-service.

## Security Notes

- Bearer JWT on APIs except public auth routes.
- **order-service → product-service** over HTTP with JWT (no shared DB).
- Use K8s Secrets / AWS Secrets Manager in production.

## Development

```bash
cd frontend && npm install && npm run dev
npm run lint && npm run build    # frontend/.eslintrc.cjs

export JAVA_HOME=$(/usr/libexec/java_home -v 17 2>/dev/null)   # macOS
cd user-service && mvn clean package -DskipTests
```

`*/target/` and `frontend/dist/` are gitignored. Clean with `mvn clean` and delete `frontend/dist` if needed.

## DevOps Implementation

This project was deployed on AWS using a containerized microservices architecture.

### Infrastructure

- AWS VPC with public/private subnets and NAT gateways
- Amazon EKS for Kubernetes workloads
- Terraform for infrastructure as code
- AWS Load Balancer Controller with ALB Ingress
- IAM/OIDC integration for Kubernetes workloads
- Amazon ECR for Docker images

### CI/CD

Two Jenkins pipelines automate deployment:

**Backend**

```text
GitHub → Jenkins → Maven Test → Docker Build → ECR → EKS → Rollout Verification

**Frontend**
```text
GitHub → Jenkins → npm ci → Lint → Vite Build → S3 → CloudFront Invalidation

## License

Proprietary — **Edublitz — Powered by Greamio Technologies Pvt Ltd.**  
See [LICENSE](LICENSE). All rights reserved.
## DevOps Implementation

The application was deployed as a production-style AWS development environment using containerized microservices, Kubernetes, Terraform, and Jenkins.

### AWS Infrastructure

The infrastructure was provisioned using modular Terraform and included:

- Amazon VPC
- Public and private subnets
- NAT Gateways
- Route tables
- Security groups
- IAM roles and OIDC integration
- Amazon EKS cluster
- EKS managed node group
- AWS Load Balancer Controller

### Containerization

The three Spring Boot services were containerized using Docker:

- `user-service`
- `product-service`
- `order-service`

Docker images were pushed to Amazon ECR and deployed to Amazon EKS.

```text
GitHub
   │
   ▼
Jenkins
   │
   ▼
Docker Build
   │
   ▼
Amazon ECR
   │
   ▼
Amazon EKS

Kubernetes Deployment

The services were deployed into the med-erp namespace.

kubectl get pods -n med-erp
kubectl get services -n med-erp
kubectl get ingress -n med-erp

The services used Kubernetes ClusterIP Services for internal communication, while the AWS Load Balancer Controller exposed the APIs through an Application Load Balancer.

CI/CD

Jenkins was used to automate the application delivery process.

Backend Pipeline
GitHub
   │
   ▼
Jenkins
   │
   ▼
Maven Build
   │
   ▼
Docker Build
   │
   ▼
Amazon ECR
   │
   ▼
Amazon EKS
   │
   ▼
Deployment Verification
Frontend Pipeline
GitHub
   │
   ▼
Jenkins
   │
   ▼
npm ci
   │
   ▼
Lint
   │
   ▼
Vite Build
   │
   ▼
Amazon S3
   │
   ▼
CloudFront

Jenkins pipeline definitions are available in:

jenkins/
├── Jenkinsfile.backend
├── Jenkinsfile.frontend
└── Jenkinsfile.infra
Frontend Deployment

The React/Vite frontend was deployed using:

React/Vite
    │
    ▼
Jenkins
    │
    ▼
Amazon S3
    │
    ▼
CloudFront CDN

CloudFront served the static frontend while API requests were routed toward the Kubernetes Application Load Balancer.

Database

MongoDB Atlas was used as the managed database layer for the microservices.

Each service maintains its own database boundary:

user-service     → users database
product-service  → products database
order-service    → orders database
Application Security
JWT-based authentication
Role-based authorization
Authenticated service-to-service communication
Kubernetes Secrets for sensitive configuration
Environment files excluded from version control
No production credentials committed to Git
Deployment Verification

The deployed environment was verified using Kubernetes and AWS CLI commands.

Examples:

kubectl get pods -n med-erp
kubectl get services -n med-erp
kubectl get ingress -n med-erp
aws eks list-clusters --region ap-northeast-1
aws ecr describe-repositories --region ap-northeast-1

Spring Boot Actuator health endpoints were also used to verify service health.

Deployment Evidence

The project includes deployment evidence covering:

Terraform infrastructure
Amazon EKS
Kubernetes workloads
Kubernetes Services
AWS Application Load Balancer
Amazon ECR
Jenkins CI/CD
Amazon S3
CloudFront
Application health checks

The AWS environment was created as a temporary development/demo deployment and was removed after verification to avoid unnecessary cloud costs.

Note: No AWS credentials, MongoDB connection strings, JWT secrets, or other sensitive configuration should be committed to this repository.