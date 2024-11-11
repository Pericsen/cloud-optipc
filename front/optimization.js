
document.getElementById('selectionForm').addEventListener('submit', function(event) {
    event.preventDefault();

    const budget = document.getElementById('budget').value;
    const preference = document.querySelector('input[name="preference"]:checked').value;

    fetch('https://your-api-url.com/optimize', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            budget: parseInt(budget),
            components: [preference]
        })
    })
    .then(response => response.json())
    .then(data => {
        const resultContainer = document.getElementById('result-container');
        resultContainer.innerHTML = "<h3>Recommended Components:</h3><ul>" +
            data.components.map(item => "<li>" + item + "</li>").join("") +
            "</ul>";
    })
    .catch(error => console.error('Error:', error));
});

function resetForm() {
    document.getElementById('selectionForm').reset();
    document.getElementById('result-container').innerHTML = "";
}
