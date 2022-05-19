import path from 'path';
import { fileURLToPath } from 'url';
import express from 'express';
import QRCode from 'qrcode';
import sparko from 'sparko-client';
import { webcrypto } from 'crypto'

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const app = express();

app.set('view engine', 'pug');
app.set('views', path.join(__dirname, 'views'));
app.use(express.static(path.join(__dirname, 'static')));

const client = sparko('http://localhost:9737', process.env.SPARK_KEY)

function getlabel() {
  return webcrypto.randomUUID().split('-')[0]
}

const label = getlabel()
const invoiceTemplate = [ '1000sat', label, 'test invoice', 60 ]

client.invoice_payment = data => {
  let { label, msat } = data.invoice_payment
  console.log(`invoice ${label} was paid with ${msat}`)
}

app.get('/', async (req, res) => {
  console.log(req)
  res.send("We are live!")
});

app.get('/pay', async (req, res) => {
  let { bolt11, preimage } = await client.call('invoice', invoiceTemplate);
  let image = await QRCode.toDataURL(bolt11);
  console.log('Bolt11:', bolt11)
  return res.render('index', { title: 'Invoice Test', image: image, bolt11: bolt11 })
});

console.info('Node Environment:', process.env.NODE_ENV || 'PRODUCTION');
app.listen(3000, "0.0.0.0");