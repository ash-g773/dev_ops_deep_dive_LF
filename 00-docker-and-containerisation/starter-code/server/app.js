const express = require("express")
const cors = require("cors")

const logger = require("./logger")
const countryRouter = require("./routers/countries")

const app = express()
app.use(express.json())
app.use(cors())
app.use(logger)

app.use("/countries", countryRouter)

module.exports = app