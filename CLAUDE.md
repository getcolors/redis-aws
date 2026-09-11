# CLAUDE.md

Guidance for agents working in this deployment. Read
`~/code/getcolors/CLAUDE.md` first.

## What this is

Desired state only. No source code. `colors.yml` is the single file to edit;
everything else is either generated (`.colors/`), secret (`.envrc.private`), or
an installed copy of the [`redis`](https://github.com/getcolors/redis) Package
Skill launchers.

The launcher payload is installed after the package's tri-colour release is
pinned. Until `.agents/skills/package-redis-*/` and `skills-lock.json` exist,
no verb can run here.

## Things specific to this deployment

- **One machine, one service.** `redis-aws` in `us-east-1a` (`t3.small`,
  Ubuntu 24.04, 20 GiB root volume), running Redis 7.2 published on loopback
  only, in a dedicated VPC (`10.79.0.0/16`) and subnet. The security group
  opens 22 alone; `ssh redis-aws` reaches it through the block the package
  wrote.
- **The client path is a tunnel**: `ssh -L 6379:127.0.0.1:6379 redis-aws`,
  then `redis-cli -p 6379` with the password read over SSH from
  `/etc/redis/secrets/password` (`sudo -n cat`: the AMI logs in as `ubuntu`,
  not root). There is no DNS record and no public port.
- **Both S3 buckets are deployment-owned.** The state bucket
  `redis-aws-state-251213589273-us-east-1` comes from the library's managed
  backend (`s3-bucket-mode: managed`); the backup bucket
  `redis-aws-backup-251213589273-us-east-1` comes from the package's storage
  stage (`redis-storage-managed: true`). The package creates both on the first
  create and `delete` destroys both, the way it owns the machine keypair.
- **One credential pair.** `COLORS_PAR_AWS_ACCESS_KEY_ID` and
  `COLORS_PAR_AWS_SECRET_ACCESS_KEY` in `.envrc.private`; `.envrc` maps them
  onto the ambient AWS chain (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`,
  `AWS_DEFAULT_REGION=us-east-1`). Compute, state and backups all use it.
- **Keygen mode**: `~/.ssh/redis-aws` is generated and owned by the package.
  Adding `aws-ssh-authorized-keys` here would switch the deployment to opt-out
  mode.
- **Three launchers.** `./green`, `./red` and `./blue` converge the same
  desired state and share the same state bucket. Run one at a time.

## The launchers are copies

The root `./green`, `./red` and `./blue` are **copies** of
`.agents/skills/package-redis-<colour>/<colour>`, not symlinks.
`npx skills update -p` rewrites the payload and leaves the root files alone,
so the project would keep running the old pin while the lockfile claimed the
new one. After every update:

```sh
npx skills update -p
cp .agents/skills/package-redis-green/green green
cp .agents/skills/package-redis-red/red red
cp .agents/skills/package-redis-blue/blue blue
```

## Before any converge

```sh
./green build                # renders offline
./green create --dry-run     # walks the DAG, skips every side effect
```

## Afterwards

```sh
./green describe             # the host's last monitor result
./green rehearse             # fresh set, restore into a scratch instance, read back
ssh redis-aws redis-status   # monitor, completed sets, recovery marker, container
```

## Deleting

```sh
COLORS_PAR_COMPUTE_PREVENT_DESTROY=false ./green delete
```

This removes the instance, the network, the SSH config block, the machine
keypair and both S3 buckets with their contents. Nothing survives.

## Never

- Read or print `.envrc.private`.
- Edit, read as source, or commit `.colors/`.
- Export `COLORS_PAR_PROFILE`; the package refuses to run when it is set.
- Weaken `compute-prevent-destroy` in committed desired state.
- Run `create`, `rehearse` or `delete` against this deployment without
  explicit authorization.
- Touch objects in either bucket by hand, or create the buckets ahead of the
  package; the package expects to own them from creation.
