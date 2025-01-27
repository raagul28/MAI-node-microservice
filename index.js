const express = require('express');
const path = require('path'); 
const app = express();

app.use(express.static(path.join(__dirname, 'public')));

app.set('view engine', 'ejs');

// Route for the welcome page
app.get('/', (req, res) => {
    res.render('welcome'); 
});

// Route for the "HI MAI!" page
app.get('/hi', (req, res) => {
    res.render('hi', { message: 'Hi MAI!' });
});

// Health check endpoint
app.get('/health', (req, res) => {
    res.status(200).json({ status: 'ok' }); 
});

const PORT = process.env.PORT || 3000;

app.listen(PORT, '0.0.0.0', () => {
    console.log(`Server is running on port ${PORT}`);
});
