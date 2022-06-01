import getClient from 'lib/sparko-client'
import QRCode from 'qrcode'

const client = getClient()

export default async function getOffer(req, res) {

  let offerId = process.env.OFFER_ID // || await createOffer()

  let data  = await client.call('listoffers');
  let offer = data.offers.find(({offer_id}) => offer_id === offerId)

  if (!offer) {
    console.error('Unable to find offer:', offerId)
    return res.status(200).json({})
  } else {
    offer.qrcode = await QRCode.toDataURL(offer.bolt12)
    return res.status(200).json(offer)
  }
}

// async function createOffer() {
//   let data = await client.call('offer', [ 'any', 'tip-jar' ])
//   console.log('Created new offer:', data)
//   return data.offer_id
// }