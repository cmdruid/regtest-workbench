import useSWR from 'swr'

import Image  from 'next/image'
import styles from './styles.module.css'

const fetcher = (...args) => fetch(...args).then(res => res.json())

export default function OfferCode() {
  const { data, error } = useSWR('/api/getoffer', fetcher)
  
  if (error) return <div>failed to load!</div>
  if (!data) return <div>loading...</div>
  if (!data.qrcode) return <div>Unable to locate offer!</div>

  return (
    <div className={styles.qrcode}>
      <Image src={data.qrcode} alt="BOLT12 QR Code" width={300} height={300} />
    </div>
  )
}