This is a [Next.js](https://nextjs.org/) project bootstrapped with [`create-next-app`](https://github.com/vercel/next.js/tree/canary/packages/create-next-app).

## Getting Started

In order to experiment with offers, you will need to spin up two lightning nodes, open a channel, and balance the channel.

To balance a new lightning channel, have the channel recipient generate an invoice for half the capacity, and then pay the invoice with the channel creater. For example:

```
Alice opens a channel with Bob for 5,000,000,000 millisats.

Bob generates an invoice for 2,500,000,000 millisats.
bob:~# lightning-cli invoice 2500000000 "balance invoice"

Alice uses the bolt11 string to pay the invoice.
alice:~# lightning-cli pay bolt11string

You will now have a balanced channel to use for testing payments!
```

To generate an open offer, use the format **offer *amount description***.

Example: `lightning-cli offer any tip-jar`

You will receive a bolt12 string for the offer. To fetch an invoice, use **fetchinvoice *offer=bolt12string msatoshi=amount payer_note=note***.

Example: `lightning-cli fetchinvoice offer=reallylongstring msatoshi=1500000 payer_note="Thanks for the cig!"`

You will then receive a bolt12 string for an invoice with your terms. To pay the invoice, simply use **pay *bolt12invoicestring***.

Example: `lightning-cli pay bolt12invoicestring`

Once you have setup an offer and made payments to it, you should be ready to setup the rest of the demo.

First, rename `.env.local.sample` to `.env.local`. Make sure that you have the correct port forwarded on your lightning node (the one which generated the offer), and that you have the correct API key listed (check the share folder for the sparko master key). You will also need to specify your offer id, so that the API will know which associated payments to lookup.

Then run the development server:

```bash
npm run dev
# or
yarn dev
```

Open [http://localhost:3000](http://localhost:3000) with your browser to see the result.

You can start editing the page by modifying `pages/index.js`. The page auto-updates as you edit the file.

## Learn More

To learn more about Next.js, take a look at the following resources:

- [Next.js Documentation](https://nextjs.org/docs) - learn about Next.js features and API.
- [Learn Next.js](https://nextjs.org/learn) - an interactive Next.js tutorial.

You can check out [the Next.js GitHub repository](https://github.com/vercel/next.js/) - your feedback and contributions are welcome!

## Deploy on Vercel

The easiest way to deploy your Next.js app is to use the [Vercel Platform](https://vercel.com/new?utm_medium=default-template&filter=next.js&utm_source=create-next-app&utm_campaign=create-next-app-readme) from the creators of Next.js.

Check out our [Next.js deployment documentation](https://nextjs.org/docs/deployment) for more details.
