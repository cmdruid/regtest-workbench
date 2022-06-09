import useSWR from 'swr'

import styles from './styles.module.css'

const fetcher = (...args) => fetch(...args).then(res => res.json())

export default function PaymentStream() {
  const { data, error } = useSWR('/api/getpayments', fetcher)
  
  if (error) return <div>failed to load!</div>
  if (!data) return <div>loading...</div>

  const paymentList = []

  for (let payment of data) {
    let text = JSON.stringify(payment, null, 2)
    paymentList.push(<p><pre className={styles.payment}>{text}</pre></p>)
  }

  return (
    <div className={styles.paymentList}>
      <h2>Latest Tips</h2>
      {paymentList && paymentList || <p>No payments yet!</p>}
    </div>
  )
}