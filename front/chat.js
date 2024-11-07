
let domain, user_pool_client_id, user_pool_id, identity_pool_id, role, api_gateway_id;

function loadConfig() {
  return fetch('./config.json')
      .then(response => {
          if (!response.ok) {
              throw new Error('Network response was not ok');
          }
          return response.json();
      })
      .then(config => {
          // Asignar valores a las variables globales
          domain = config.domain;
          user_pool_client_id = config.user_pool_client_id;
          user_pool_id = config.user_pool_id;
          identity_pool_id = config.identity_pool_id;
          role = config.role;
          api_gateway_id = config.api_gateway_id;

          init();
      })
      .catch(error => {
          console.error('There was a problem with the fetch operation:', error);
      });
}

function init() {

  AWS.config.region = 'us-east-1';
  AWS.config.credentials = new AWS.CognitoIdentityCredentials({
      IdentityPoolId: identity_pool_id
  });

  // Inicializa el usuario
  var poolData = {
      UserPoolId: user_pool_id,
      ClientId: user_pool_client_id
  };
  var userPool = new AmazonCognitoIdentity.CognitoUserPool(poolData);

  console.log(api_gateway_id);
  console.log(user_pool_id);
  console.log(user_pool_client_id);
  console.log(poolData);
  console.log(userPool);
  console.log(userPool.getCurrentUser());

  //////// VINCULACIÓN A LA UI DE INICIO DE SESIÓN DE COGNITO
  const loginButton = document.getElementById("login-btn");
  if (loginButton) {
    loginButton.addEventListener("click", async function () {
      const cognitoLoginUrl = `https://${domain}.auth.us-east-1.amazoncognito.com/login?response_type=code&client_id=${user_pool_client_id}&redirect_uri=https://${api_gateway_id}.execute-api.us-east-1.amazonaws.com/prod/redirect`;
      window.location.href = cognitoLoginUrl;
    });
  }

  function getUserData() {
    var cognitoUser = userPool.getCurrentUser();

    if (cognitoUser) {
        cognitoUser.getSession((err, session) => {
            if (err) {
                console.error(err);
                return;
            }
            console.log("Sesión obtenida con éxito:", session);

            // Obtiene los atributos del usuario
            cognitoUser.getUserAttributes((err, attributes) => {
                if (err) {
                    console.error(err);
                    return;
                }
                console.log("Atributos del usuario obtenidos:", attributes)

                // Procesa los atributos y actualiza la UI
                let username = '';
                let email = '';
                // let profilePic = ''; // Puedes configurar una imagen predeterminada o usar un servicio de imágenes

                attributes.forEach(attribute => {
                    if (attribute.getName() === 'email') {
                        email = attribute.getValue();
                    }
                    if (attribute.getName() === 'name') {
                        username = attribute.getValue();
                    }
                    // Si tienes un atributo de foto de perfil, puedes obtenerlo aquí
                });

                // Actualiza la interfaz de usuario
                document.getElementById("login-btn").style.display = "none";
                document.getElementById("profile").style.display = "flex";
                // document.getElementById("profile-pic").src = profilePic || 'https://via.placeholder.com/40'; // Imagen predeterminada
                document.getElementById("username").innerText = username;
                document.getElementById("popup-username").innerText = `Usuario: ${username}`;
                document.getElementById("popup-email").innerText = `Email: ${email}`;
            });
        });
    }
  };

  // Llama a la función para obtener los datos del usuario después de que se haya iniciado sesión
  window.onload = function() {
    getUserData();
  };

  // Manejo del clic en el perfil
  const profile = document.getElementById("profile");
  if (profile) {
    profile.addEventListener("click", function () {
      const popup = document.getElementById("profile-popup");
      popup.style.display = popup.style.display === "none" ? "block" : "none";
    });
  }

  // Cierre de sesión
  const logout_btn = document.getElementById("logout-btn");
  if (logout_btn) {
    logout_btn.addEventListener("click", function () {
      if (cognitoUser) {
          cognitoUser.signOut();
          location.reload(); // Recarga la página para reflejar el estado de cierre de sesión
      }
    });
  }


  // //////// UPLOAD DATA EN DYNAMO
  document.getElementById('upload-popup').onclick = function() {
      document.getElementById('overlay').style.display = 'block';
      document.getElementById('uploadPopup').style.display = 'block';
  };

  // Función para cerrar el popup
  document.getElementById('closePopup').onclick = function() {
      document.getElementById('overlay').style.display = 'none';
      document.getElementById('uploadPopup').style.display = 'none';
  };

  function displayPreview(csvData) {
        const previewContainer = document.getElementById("tableContainer");
        previewContainer.innerHTML = ""; // Limpiar cualquier vista previa anterior

        // Separar líneas y obtener los primeros 5 registros para la vista previa
        const rows = csvData.split("\n").slice(0, 5);
        const table = document.createElement("table");
        table.classList.add("csv-preview-table");

        rows.forEach((row, index) => {
            const rowElement = document.createElement("tr");
            const cells = row.split(",");

            cells.forEach(cell => {
                const cellElement = index === 0 ? document.createElement("th") : document.createElement("td");
                cellElement.textContent = cell.trim();
                rowElement.appendChild(cellElement);
            });

            table.appendChild(rowElement);
        });

        previewContainer.appendChild(table);
    }

  // Función para mostrar el display del csv
  document.getElementById("csvFile").addEventListener("change", function (event) {
      const file = event.target.files[0];
      if (file) {
          const reader = new FileReader();
          reader.onload = function (e) {
              const text = e.target.result;
              displayPreview(text);
          };
          reader.readAsText(file);
      }
  });

  // Función para manejar la subida del CSV
  document.getElementById('uploadButton').onclick = async function() {
      const fileInput = document.getElementById('csvFile');
      const file = fileInput.files[0];

      if (!file) {
          alert("Por favor, selecciona un archivo CSV.");
          return;
      }

      const reader = new FileReader();
      reader.onload = async function(event) {
          const csvData = event.target.result;
        
          try {
              const response = await fetch(`https://${api_gateway_id}.execute-api.us-east-1.amazonaws.com/prod/upload`, {
                // const response = await fetch(`https://${api_gateway_id}.execute-api.us-east-1.amazonaws.com/prod`, {
                  method: 'POST',
                  headers: {
                      'Content-Type': 'application/json'
                  },
                  body: JSON.stringify({ data: csvData })
              });

              if (!response.ok) {
                  throw new Error('Error al cargar el archivo CSV');
              }

              const result = await response.json();
              console.log('Archivo CSV cargado exitosamente:', result);
              alert('Archivo cargado exitosamente');

              // Cerrar el popup después de la carga
              document.getElementById('overlay').style.display = 'none';
              document.getElementById('uploadPopup').style.display = 'none';
          } catch (error) {
              console.error('Error:', error);
              alert('Error al cargar el archivo CSV: ' + error.message);
          }

      };

      reader.readAsText(file);
  };


  //////// OPTIMIZACIÓN

  let selectedComponents = [];

  document.getElementById("optimize-btn").addEventListener("click", async function () {
    const budget = parseFloat(document.getElementById('budget').value);
    const resultsSection = document.getElementById('results');
    resultsSection.innerHTML = ''; // Clear previous results
  
    if (selectedComponents.length === 0) {
      alert("Por favor, selecciona al menos un componente.");
      return;
    }

    const data = {
        budget: budget,
        components: selectedComponents
    };

    try {
        // Llamada a la API Gateway
        console.log(api_gateway_id);
        // api_gateway_id = 'tttb1lgx98'
        // console.log(api_gateway_id);

        const response = await fetch(`https://${api_gateway_id}.execute-api.us-east-1.amazonaws.com/prod/send`, {
            method: 'POST',
            body: JSON.stringify(data),
            headers: {
                'Content-Type': 'application/json'
            }
        });

        if (response.ok) {
            const result = response.json();
            displayResults(result);
        } else {
            console.error('Error en la optimización:', response.status);
        }
    } catch (error) {
        console.error('Error en la solicitud de optimización:', error);
    }
  });


  function displayResults(data) {
      console.log('Resultado recibido:', data);  // Verifica qué datos estás recibiendo

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
}

loadConfig();