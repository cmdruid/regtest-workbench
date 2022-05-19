import lnurl from "lnurl"

const server = lnurl.createServer({
  host: 'localhost',
	port: 3001,
  url: 'http://y6qq5b3akqqorrqbpvd7zsgmpv7eq3rzesrcdsz52febghi3txoy4vqd.onion',
  endpoint: '/lnurl',
	// auth: {
	// 	apiKeys: [
	// 		{
	// 			id: '46f8cab814de07a8a65f',
	// 			key: '02010b632d6c696768746e696e67023e576564204d617920313120323032322030363a35343a313220474d542b303030302028436f6f7264696e6174656420556e6976657273616c2054696d6529000006204bd45cf9f4f8f40b2154d7da4ab95fe1735259d3d18fdc82937568e8f1b3287f',
	// 			encoding: 'hex',
	// 		},
	// 	],
	// },
  lightning: {
    backend: 'c-lightning',
    config: {
      unixSockPath: "/data/lightning/regtest/lightning-rpc"
    }
  }
  // store: {
  //   backend: 'knex',
  //   config: {
  //     client: 'sqlite3',
  //     connection: {
  //       filename: './data/lnurl-server.sqlite3',
  //     }
  //   }
  // },
})

// server.on('login', function(event) {
// 	// The event object varies depending upon the event type.
//   const { key, hash } = event;
//   console.log(`Server logged in with: ${key} ${hash}`)
// });

// server.bindToHook('login', function(key, next) {
//   console.log('login Key: ', key)
//   next()
// });

// server.bindToHook('url:signed', function(req, res, next) {
//   console.log('req: ', req)
//   console.log('res: ', res)
//   next()
// });

// server.bindToHook('channelRequest:validate', function(params, next) {
//   console.log('params: ', params)
//   next()
// });

// server.bindToHook('channelRequest:info', function(secret, params, next) {
//   console.log('secret: ', secret)
//   console.log('params: ', params)
//   next()
// });

// server.on('payRequest:action:processed', function(event) {
//   const { secret, params, result } = event;
//   const { id, invoice } = result;
//   // `id` - non-standard reference ID for the new invoice, can be NULL if none provided
//   // `invoice` - bolt11 invoice
//   console.log('payrequest result: ', result)
// });

// server.on('payRequest:action:failed', function(event) {
//   const { secret, params, error } = event;
//   // `error` - error from the LN backend
//   console.log('error: ', error)
// });

export default server
