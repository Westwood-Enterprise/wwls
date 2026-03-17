const express = require('express')
const { Sequelize } = require('sequelize')
const passportLocalSequelize = require('passport-local-sequelize')
const app = express()
const port = 3000
const sequelize = new Sequelize({
  dialect: 'sqlite',
  storage: './main.sqlite',
  logging: false,
})

const User = passportLocalSequelize.defineUser(sequelize)

app.use(express.json())

const registerUser = (username, password) =>
  new Promise((resolve, reject) => {
    User.register({ username }, password, (err, user) => {
      if (err) {
        reject(err)
        return
      }

      resolve(user)
    })
  })

const authenticateUser = (username, password) =>
  new Promise((resolve, reject) => {
    const auth = User.authenticate()
    auth(username, password, (err, user, info) => {
      if (err) {
        reject(err)
        return
      }

      resolve({ user, info })
    })
  })

const initializeDatabase = async () => {
  await sequelize.authenticate()
  await sequelize.sync()
}

app.get('/', (req, res) => {
  res.send('Hello World!')
})

app.post('/signup', async (req, res) => {
  const { username, password } = req.body ?? {}

  if (typeof username !== 'string' || typeof password !== 'string') {
    res.status(400).json({ error: 'username and password are required' })
    return
  }

  const normalizedUsername = username.trim()
  if (!normalizedUsername || password.length < 8) {
    res.status(400).json({ error: 'invalid username or password too short' })
    return
  }

  try {
    await registerUser(normalizedUsername, password)
    res.status(201).json({ message: 'account created' })
  } catch (err) {
    if (err && /User already exists/.test(String(err.message))) {
      res.status(409).json({ error: 'username already exists' })
      return
    }

    console.error('signup error', err)
    res.status(500).json({ error: 'internal server error' })
  }
})

app.post('/login', async (req, res) => {
  const { username, password } = req.body ?? {}

  if (typeof username !== 'string' || typeof password !== 'string') {
    res.status(400).json({ error: 'username and password are required' })
    return
  }

  try {
    const normalizedUsername = username.trim()
    const { user, info } = await authenticateUser(normalizedUsername, password)
    if (!user) {
      res.status(401).json({ error: 'invalid credentials' })
      return
    }

    res.status(200).json({
      message: 'login successful',
      user: { id: user.id, username: user.username },
      info,
    })
  } catch (err) {
    console.error('login error', err)
    res.status(500).json({ error: 'internal server error' })
  }
})

initializeDatabase()
  .then(() => {
    app.listen(port, () => {
      console.log(`Example app listening on port ${port}`)
    })
  })
  .catch((err) => {
    console.error('database initialization error', err)
    process.exit(1)
  })
