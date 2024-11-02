
//////// ACCESO A PARAMETERS STORE Y SECRET MANAGER
let domain, role, api_gateway_id;

// function loadConfig() {
//   return fetch('./config.json')
//       .then(response => {
//           if (!response.ok) {
//               throw new Error('Network response was not ok');
//           }
//           return response.json();
//       })
//       .then(config => {
//           // Asignar valores a las variables globales
//           domain = config.domain;
//           user_pool_client_id = config.user_pool_client_id;
//           identity_pool_id = config.identity_pool_id;
//           role = config.role;
//           api_gateway_id = config.api_gateway_id;

//           init();
//       })
//       .catch(error => {
//           console.error('There was a problem with the fetch operation:', error);
//       });
// }

//function init() {
  // console.log(identity_pool_id)


  // AWS.config.update({
  //   region: 'us-east-1',
  //   credentials: new AWS.CognitoIdentityCredentials({
  //       IdentityPoolId: identity_pool_id,
  //       RoleArn: role
  //   })
  // });

  //////// VINCULACIÓN A LA UI DE INICIO DE SESIÓN DE COGNITO
  // document.getElementById("login-btn").addEventListener("click", async function () {
  //     try {
  //         // const user_pool_client_id = await getParameterStoreValue("myapp/user_pool_client_id");

  //         // console.log(identity_pool_id);
          
  //         // AWS.config.update({
  //         //   region: 'us-east-1',
  //         //   credentials: new AWS.CognitoIdentityCredentials({
  //         //       IdentityPoolId: identity_pool_id
  //         //   })
  //         // });

  //         // Refresca las credenciales para asegurarte de que están disponibles
  //         AWS.config.credentials.get(async function(err) {
  //             if (err) {
  //                 console.error("Error al obtener credenciales:", err);
  //                 return;
  //             }

  //             // Ahora que tenemos las credenciales, podemos continuar
  //             // const domain = await getParameterStoreValue("/myapp/domain");
              
  //             const cognitoLoginUrl = `https://${domain}.auth.us-east-1.amazoncognito.com/login?response_type=code&client_id=${user_pool_client_id}&redirect_uri=https://${api_gateway_id}.execute-api.us-east-1.amazonaws.com/prod/lambda1`;
  //                                   // https://optipc.auth.us-east-1.amazoncognito.com/login?response_type=code&client_id=71nn0chfv0k7kp8gaktslu33s1&redirect_uri=https://5wz2ixk0vg.execute-api.us-east-1.amazonaws.com/prod/lambda1

  //             // Redirige a la URL de inicio de sesión
  //             window.location.href = cognitoLoginUrl;
  //         });

  //     } catch (err) {
  //         console.error("Error al obtener los secretos o parámetros:", err);
  //     }
  // });

  //////// OPTIMIZACIÓN

let selectedComponents = [];

async function optimize() {
    const budget = parseFloat(document.getElementById('budget').value);
    const resultsSection = document.getElementById('results');
    resultsSection.innerHTML = ''; // Limpiamos resultados previos
    
    if (selectedComponents.length === 0) {
        alert("Por favor, selecciona al menos un componente.");
        return;
    }

    // Datos que se enviarán a la Lambda
    const data = {
        budget: budget,
        components: selectedComponents
    };

    try {
        // Llamada a la API Gateway
        const response = await fetch(`https://4lro0qkd83.execute-api.us-east-1.amazonaws.com/v1/optimize`, {
            method: 'POST',
            body: JSON.stringify(data),
            headers: {
                'Content-Type': 'application/json'
            }
        });

        if (response.ok) {
            const result = await response.json();
            displayResults(result);  // Muestra los resultados desde la Lambda
        } else {
            console.error('Error en la optimización:', response.status);
        }
    } catch (error) {
        console.error('Error en la solicitud de optimización:', error);
    }
}

// Función para mostrar resultados recibidos desde la Lambda
function displayResults(data) {
    const resultsSection = document.getElementById('results');
    resultsSection.innerHTML = ''; // Limpiamos resultados previos

    let totalPrice = 0;

    // Iteramos sobre los componentes optimizados recibidos desde la Lambda
    data.optimized_components.forEach(component => {
        const componentDiv = document.createElement('div');
        componentDiv.classList.add('component-item');

        const componentImg = document.createElement('img');
        componentImg.src = `images/${component.name}.png`; // La imagen del componente correspondiente
        componentDiv.appendChild(componentImg);

        const componentInfo = document.createElement('div');
        componentInfo.classList.add('component-info');
        componentInfo.innerHTML = `<h3>${component.name.toUpperCase()}</h3>`;
        componentDiv.appendChild(componentInfo);

        const priceDiv = document.createElement('div');
        priceDiv.classList.add('price');
        priceDiv.innerHTML = `$${component.price}`;
        componentDiv.appendChild(priceDiv);

        totalPrice += component.price;
        resultsSection.appendChild(componentDiv);
    });

    // Mostrar el precio total
    const totalDiv = document.createElement('div');
    totalDiv.classList.add('total-price');
    totalDiv.innerHTML = `Total: $${totalPrice}`;
    
    if (totalPrice <= budget) {
        totalDiv.style.color = '#00ffab'; // Verde si está dentro del presupuesto
    } else {
        totalDiv.style.color = '#ff4d4d'; // Rojo si excede el presupuesto
    }
    resultsSection.appendChild(totalDiv);

    // Mostrar la diferencia entre presupuesto y precio total
    const difference = budget - totalPrice;
    const differenceDiv = document.createElement('div');
    differenceDiv.classList.add('price-difference');
    
    if (difference >= 0) {
        differenceDiv.innerHTML = `Ahorras $${Math.abs(difference.toFixed(2))}`;
        const triangleDown = document.createElement('div');
        triangleDown.classList.add('triangle-down');
        differenceDiv.appendChild(triangleDown);
    } else {
        differenceDiv.innerHTML = `Excedes por $${Math.abs(difference.toFixed(2))}`;
        const triangleUp = document.createElement('div');
        triangleUp.classList.add('triangle-up');
        differenceDiv.appendChild(triangleUp);
    }

    resultsSection.appendChild(differenceDiv);
}
    
  // Event listener for adding components dynamically
document.getElementById('priority-components').addEventListener('change', function (event) {
  const selectedComponent = event.target.value;
    
  if (selectedComponent !== 'Agregar Prioridad') {
    selectedComponents.push(selectedComponent);

    const newSelector = document.createElement('select');
    newSelector.classList.add('component-selector');
    newSelector.innerHTML = `
      <option>Agregar Prioridad</option>
      <option value="cpu">CPU</option>
      <option value="gpu">GPU</option>
      <option value="ram">RAM</option>
      <option value="storage">Almacenamiento</option>
    `;
    document.getElementById('priority-components').appendChild(newSelector);

    // Disable the current option to avoid re-selection
    event.target.disabled = true;
    }
});


// loadConfig();