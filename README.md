# Agoston graphile

## Env rebuild

```bash
# system req: https://github.com/niolap/agoston-postgres/blob/main/Dockerfile
apt install -y python3 python3-pip postgresql-plpython3-15
pip3 install requests
```

```bash
./test_reset_db.sh
```

## Run backend

```bash
. ./src/test/test_environment.sh
npm run serve --prefix ./src
```

## Test

```bash
. ./src/test/test_environment.sh
# export SKIP_FINAL_CLEANUP=1
./src/test/test.sh
```


## Stripe

```
stripe listen --forward-to localhost:4000/hook/stripe
```
