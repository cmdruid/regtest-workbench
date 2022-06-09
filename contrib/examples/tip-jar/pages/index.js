import Head from 'next/head'
import Image from 'next/image'
import styles from '../styles/Home.module.css'

import OfferCode from 'components/OfferCode/index.js'
import PaymentStream from 'components/PaymentStream/index.js'

export default function Home() {
  return (
    <div className={styles.container}>
      <Head>
        <title>Just The Tip Jar</title>
        <meta name="description" content="Just The Tip Jar" />
        <link rel="icon" href="/favicon.ico" />
      </Head>

      <main className={styles.main}>
        <h1 className={styles.title}>
          Welcome to Just The Tip Jar
        </h1>

        <p className={styles.description}>
          Testing the API with our lightning node!
        </p>

        <OfferCode />
        <PaymentStream />
      </main>

      <footer className={styles.footer}>
        <a
          href="https://vercel.com?utm_source=create-next-app&utm_medium=default-template&utm_campaign=create-next-app"
          target="_blank"
          rel="noopener noreferrer"
        >
          Powered by{' '}
          <span className={styles.logo}>
            <Image src="/vercel.svg" alt="Vercel Logo" width={72} height={16} />
          </span>
        </a>
      </footer>
    </div>
  )
}
