This is a [monorepo](https://semaphoreci.com/blog/what-is-monorepo) for Kali Wrappr.

# Wrappr Structure

![Screenshot 2022-09-14 055201](https://user-images.githubusercontent.com/13903299/190007927-0b9622e3-246c-4bb8-835d-2208c6149180.png)

# Repo Structure

```ml
 ├─ frontend - "React, nextjs, ethers, wagmi, rainbowkit"
 │─ backend - "Subgraph scripts for Kali nodes on TheGraph network"
 │─ contracts - "Solidity smart contracts, hardhat setup"
 │─ e2e-tests - "End-to-end full stack tests"

```

Each of the above subdirectories has its own README file with additional information.

# Dockerized services

Each of the services in the monorepo can be started separately or all together via [docker-compose](https://docs.docker.com/compose/).

```bash
docker-compose up frontend
```

```bash
docker-compose up backend
```

```bash
docker-compose up contracts
```

To start all together:

```bash
docker-compose up
```

To start all in daemon mode
```bash
docker-compose up -d
```

To watch log files in daemon mode
```bash
docker-compose logs --follow
```
