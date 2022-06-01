import sparko from 'sparko-client'

let clientCache;

export default function getClient() {
  if (!clientCache) {
    clientCache = sparko(process.env.SPARK_URL, process.env.SPARK_KEY)
    console.log('Spark client now listening on:', process.env.SPARK_URL)
  }
  return clientCache
}
