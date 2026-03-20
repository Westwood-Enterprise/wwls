const express = require('express')
const jwt = require('jsonwebtoken')
const { Sequelize } = require('sequelize')
const passportLocalSequelize = require('passport-local-sequelize')
const app = express()
const port = 3000
const jwtSecret = process.env.JWT_SECRET || 'local-dev-secret-change-me'
const jwtExpiry = '30d'
const sequelize = new Sequelize({
  dialect: 'sqlite',
  storage: './main.sqlite',
  logging: false,
})

const User = passportLocalSequelize.defineUser(sequelize)

app.use(express.json())

const issueAuthToken = (user) => {
  const token = jwt.sign(
    {
      sub: String(user.id),
      username: user.username,
    },
    jwtSecret,
    { expiresIn: jwtExpiry }
  )

  const decoded = jwt.decode(token)
  return {
    token,
    expiresAt: decoded && decoded.exp ? decoded.exp * 1000 : null,
  }
}

const getBearerToken = (req) => {
  const authHeader = req.headers.authorization
  if (!authHeader || typeof authHeader !== 'string') {
    return null
  }

  const [scheme, token] = authHeader.split(' ')
  if (scheme !== 'Bearer' || !token) {
    return null
  }

  return token
}

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
    const user = await registerUser(normalizedUsername, password)
    const auth = issueAuthToken(user)

    res.status(201).json({
      message: 'account created',
      user: { id: user.id, username: user.username },
      token: auth.token,
      tokenExpiresAt: auth.expiresAt,
    })
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

    const auth = issueAuthToken(user)

    res.status(200).json({
      message: 'login successful',
      user: { id: user.id, username: user.username },
      info,
      token: auth.token,
      tokenExpiresAt: auth.expiresAt,
    })
  } catch (err) {
    console.error('login error', err)
    res.status(500).json({ error: 'internal server error' })
  }
})

app.post('/token/renew', async (req, res) => {
  const token = getBearerToken(req)
  if (!token) {
    res.status(401).json({ error: 'missing bearer token' })
    return
  }

  try {
    const payload = jwt.verify(token, jwtSecret)
    const userId = payload && payload.sub ? Number(payload.sub) : NaN
    if (!userId || Number.isNaN(userId)) {
      res.status(401).json({ error: 'invalid token subject' })
      return
    }

    const user = await User.findByPk(userId)
    if (!user) {
      res.status(401).json({ error: 'user not found' })
      return
    }

    const auth = issueAuthToken(user)
    res.status(200).json({
      message: 'token renewed',
      token: auth.token,
      tokenExpiresAt: auth.expiresAt,
      user: { id: user.id, username: user.username },
    })
  } catch (_) {
    res.status(401).json({ error: 'invalid or expired token' })
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
