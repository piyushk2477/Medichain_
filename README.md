# Medichain

A decentralized medical-records app. Patients own their data, control access
cryptographically, and every grant/view/download is logged on-chain as an
immutable audit trail.

The project is split into **three independently-runnable parts**, each in its
own folder — so the frontend, backend, and blockchain can run on separate
machines/servers:

```
Medichain/
├── lib/          → Flutter app  (FRONTEND — pure UI, talks only to the backend)
├── backend/      → Express/Node (BACKEND  — Supabase, IPFS, encryption, chain)
└── blockchain/   → Hardhat      (CHAIN    — the MediAccessControl contract)
```

## Architecture

```
┌───────────────┐      HTTPS/REST      ┌────────────────────┐
│  Flutter app  │  ───────────────────▶│  Express backend   │
│    (lib/)     │   Bearer token JWT   │    (backend/)      │
└───────────────┘                      └─────────┬──────────┘
   pure frontend                                 │
   no secrets on device          ┌───────────────┼───────────────┐
                                  ▼               ▼               ▼
                             ┌─────────┐    ┌──────────┐   ┌────────────┐
                             │ Supabase│    │  Pinata  │   │  Hardhat / │
                             │ auth+db │    │  (IPFS)  │   │  Polygon   │
                             └─────────┘    └──────────┘   └────────────┘
```

| Part | Tech | Responsibility |
|---|---|---|
| **Frontend** (`lib/`) | Flutter (Dart) | Patient & doctor screens. Talks **only** to the backend over REST. Holds no secrets. |
| **Backend** (`backend/`) | Express / Node.js | Auth, profiles, records, appointments, sharing. Owns Supabase, Pinata, AES encryption, and the blockchain signer. |
| **Blockchain** (`blockchain/`) | Solidity + Hardhat | `MediAccessControl` — on-chain access grants + immutable audit log. |

> **What changed from the original single-app design:** the backend logic used
> to live inside the Flutter app's `lib/services/`. It now lives in `backend/`
> and runs as its own server. Files are still AES-encrypted before hitting IPFS,
> but the encryption, the Pinata JWT, and the Ethereum keys are all **server-side
> now** — nothing sensitive ships inside the app.

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) ≥ 3.10 (frontend)
- [Node.js](https://nodejs.org/) ≥ 18 (backend + blockchain)
- An Android emulator or physical device (iOS/desktop/web work too)
- Free accounts on [Supabase](https://supabase.com) and [Pinata](https://app.pinata.cloud)

## First-time setup

### 1. Clone

```bash
git clone https://github.com/piyushk2477/Medichain.git
cd Medichain
```

### 2. Set up the backend (`backend/`)

```bash
cd backend
npm install
cp .env .env      # then fill in the values below
```

Fill `backend/.env`:

| Variable | Where to get it |
|---|---|
| `SUPABASE_URL`, `SUPABASE_ANON_KEY` | Supabase → Project Settings → API |
| `SUPABASE_SERVICE_ROLE_KEY` | same page (the **service_role** secret — server only) |
| `PINATA_JWT`, `PINATA_GATEWAY` | Pinata → API Keys (`pinFileToIPFS`) + Gateways tab |
| `BLOCKCHAIN_RPC_URL`, `BLOCKCHAIN_CHAIN_ID`, `CONTRACT_ADDRESS` | your node + deployed contract |
| `WALLET_ENCRYPTION_KEY` | `node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"` |

Then run the **one-time database migration** — open the Supabase dashboard →
SQL Editor → paste and run [`backend/db/migrations.sql`](backend/db/migrations.sql)
(it adds the `user_wallets` table the backend needs to custody Ethereum keys).

Full backend docs: [backend/README.md](backend/README.md).

### 3. Set up the frontend (`lib/`)

```bash
cd ..                 # back to project root
flutter pub get
cp .env .env
```

Edit the app's `.env` — it now holds a single value, the backend URL:

```
API_BASE_URL=http://10.0.2.2:3000
```

| Running the app on | `API_BASE_URL` |
|---|---|
| Android emulator | `http://10.0.2.2:3000` (the emulator's alias for the host's localhost) |
| iOS simulator / desktop / web | `http://localhost:3000` |
| Physical phone (same Wi-Fi) | `http://<your-laptop-LAN-IP>:3000` |
| Deployed backend | `https://your-backend.example.com` |

### 4. (Optional) Set up the blockchain (`blockchain/`)

Only needed if you want the on-chain access log / grants to work. See
[blockchain/README.md](blockchain/README.md). For local dev:

```bash
cd blockchain
npm install
```

## Running the project

You need up to **four** processes. Start them in this order:

### Terminal 1 — (optional) local blockchain node

```bash
cd blockchain
npx hardhat node
```

Exposes a local JSON-RPC at `http://127.0.0.1:8545`, chain id `31337`.

### Terminal 2 — (optional) deploy the contract

```bash
cd blockchain
npx hardhat run scripts/deploy.js --network localhost
```

Copy the printed `MediAccessControl` address into `backend/.env`'s
`CONTRACT_ADDRESS` (the first deploy against a fresh node is always
`0x5FbDB2315678afecb367f032d93F642f64180aa3`).

### Terminal 3 — the backend

```bash
cd backend
npm run dev
```

You should see `MediChain backend listening on http://localhost:3000`.
Verify with `curl http://localhost:3000/health`.

> **The backend must be reachable from wherever the app runs.** On an Android
> emulator the app reaches your laptop's `localhost` via `10.0.2.2` — that's why
> `API_BASE_URL` defaults to `http://10.0.2.2:3000`. On a physical phone, use
> your laptop's LAN IP and make sure the firewall allows port 3000.

### Terminal 4 — the Flutter app

```bash
flutter run
```

## Deploying the backend to another server

Because the backend is a standalone Express app, you can host it anywhere Node
runs (Render, Railway, Fly.io, a VPS…):

1. Set the same `.env` variables in the host environment.
2. Run `backend/db/migrations.sql` against your Supabase project once.
3. `npm ci && npm start`.
4. Point the app's `API_BASE_URL` at the deployed HTTPS URL and rebuild.

See [backend/README.md](backend/README.md#deploying-to-another-server) for the
blockchain caveat (a cloud backend can't reach a local Hardhat node).

## Project structure

```
.
├── lib/                        # Flutter FRONTEND
│   ├── main.dart               #   entry point; loads API_BASE_URL, restores session
│   ├── screens/                #   patient + doctor UI (unchanged UX)
│   └── services/               #   thin REST clients to the backend
│       ├── api_client.dart         # HTTP + auth-token plumbing
│       ├── supabase_service.dart   # auth + session (name kept for compatibility)
│       ├── doctor_service.dart     # doctors
│       ├── doctor_request_service.dart # connection requests
│       ├── profile_service.dart    # profiles + patients
│       ├── records_service.dart    # medical records
│       ├── upload_service.dart     # upload pipeline (multipart → backend)
│       ├── sharing_service.dart    # patient→doctor sharing
│       ├── appointment_service.dart
│       ├── contract_service.dart   # blockchain reads/logs
│       └── wallet_service.dart     # wallet address lookup
├── backend/                    # Express BACKEND (see backend/README.md)
│   ├── src/routes/             #   REST endpoints
│   ├── src/services/           #   encryption, Pinata, wallet, contract, email
│   └── db/migrations.sql       #   one-time Supabase migration
├── blockchain/                 # Hardhat + MediAccessControl.sol
├── .env                        # gitignored — API_BASE_URL only
└── backend/.env                # gitignored — all server secrets
```

## Troubleshooting

| Problem | Fix |
|---|---|
| App shows a network/connection error on login | The backend isn't running or `API_BASE_URL` is wrong for your target (emulator vs device). Check Terminal 3 and `curl http://localhost:3000/health`. |
| `supabaseUrl is required` when starting the backend | `backend/.env` is missing or incomplete. Copy `backend/.env.example` and fill it in. |
| Uploads fail with HTTP 401 from the backend | The Pinata JWT in `backend/.env` is wrong or revoked. Generate a new key. |
| Blockchain audit log is always empty | The backend can't reach `BLOCKCHAIN_RPC_URL`, or `CONTRACT_ADDRESS` is stale after a Hardhat restart. Redeploy and update `backend/.env`. |
| `WALLET_ENCRYPTION_KEY must be…` in backend logs | Set `WALLET_ENCRYPTION_KEY` to a 64-hex-char value in `backend/.env`. |

## Security notes

- The app ships **no secrets**. The Supabase anon key, Pinata JWT and Ethereum
  signing keys all live on the backend now.
- User-scoped reads/writes run under the caller's Supabase **Row-Level Security**
  (the backend forwards the user's token), exactly as the app did before.
- Ethereum keys are generated at signup and stored **AES-256-GCM encrypted** in
  the `user_wallets` table; only the backend's service-role key can read them.
- For a real deployment, terminate the backend behind HTTPS and lock
  `CORS_ORIGIN` down to your app's origin instead of `*`.
