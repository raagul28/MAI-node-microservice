const express = require('express');
const path = require('path'); // Ensure proper handling of static files
const app = express();

// Serve static files from the "public" directory
app.use(express.static(path.join(__dirname, 'public')));

// Set the view engine to EJS
app.set('view engine', 'ejs');

// Serve frontend at the root route
app.get('/', (req, res) => {
    res.render('index', { message: 'Hi MAI!' }); // Ensure proper message passing
});


app.get('/health', (req, res) => {
    res.status(200).json({ status: 'ok' }); 
});

const PORT = process.env.PORT || 3000;

app.listen(PORT, '0.0.0.0', () => {
    console.log(`Server is running on port ${PORT}`);
});
