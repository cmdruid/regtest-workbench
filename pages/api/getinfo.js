import getclient from 'lib/sparko-client'

const client = getclient()

export default async function getinfo(req, res) {
  let info = await client.call('getinfo');
  res.status(200).json(info)
}