# Lightning-RPC Terminal
A simple webpage to demonstrate how to connect with your clightning node, using sparko and websockets.

## How to use
> *Note: Make sure you have nodejs installed, with either yarn or npm.*
```bash
## Clone this repository.
git clone repo 
cd repo-name

## Rename `.env.sample` to `.env` and fill in your info.
SPARK_HOST=http://127.0.0.1:9737  ## Example
SPARK_KEY=put_your_sparko_master_key_here

yarn install && yarn start
  *or* 
npm install && npm start

## Visit 'https://localhost:8999' to view the page!
```