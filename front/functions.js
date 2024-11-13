let domain, user_pool_client_id, user_pool_id, api_gateway_id;
let tokenInMemory = null;

async function getToken() {
    if (tokenInMemory) {
        return tokenInMemory;
    }

    const urlParams = new URLSearchParams(window.location.search);
    const authorizationCode = urlParams.get('code'); // Obtén el código de autorización de la URL
    if (!authorizationCode) {
        console.error('No authorization code found in the URL.');
        return null;
    }
  
    // const tokenUrl = domain;
    const tokenUrl = `https://${domain}.auth.us-east-1.amazoncognito.com/oauth2/token`;

    const params = new URLSearchParams();
    params.append('grant_type', 'authorization_code');
    params.append('client_id', user_pool_client_id);
    params.append('code', authorizationCode);
    params.append('redirect_uri', `https://${api_gateway_id}.execute-api.us-east-1.amazonaws.com/prod/redirect`);

    const response = await fetch(tokenUrl, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: params
    });

    const tokenData = await response.json();

    if (response.ok) {
        const idToken = tokenData.id_token;

        // Almacenar el token en memoria
        tokenInMemory = idToken;
        return idToken;
    } else {
        console.error('Error getting token:', tokenData);
        return null;
    }
}

async function verificarPermisosAdmin() {
    const token = await getToken();
    if (token) {
        try {
            const tokenPayload = JSON.parse(atob(token.split('.')[1]));
            const userGroups = tokenPayload['cognito:groups'] || [];

            return userGroups.includes('Administradores');
        } catch (error) {
            console.error('Error al verificar permisos:', error);
            return null;
        }
    }
}

async function login() {
    //////// VINCULACIÓN A LA UI DE INICIO DE SESIÓN DE COGNITO
    const loginButton = document.getElementById("login-btn");
    if (loginButton) {
        loginButton.addEventListener("click", function () {
            const cognitoLoginUrl = `https://${domain}.auth.us-east-1.amazoncognito.com/login?response_type=code&client_id=${user_pool_client_id}&redirect_uri=https://${api_gateway_id}.execute-api.us-east-1.amazonaws.com/prod/redirect`;
            window.location.href = cognitoLoginUrl;
        });
    }

    const profile = document.getElementById("profile");
    if (profile) {
        document.getElementById('profile').onclick = async function() {
            const token = await getToken();
            if (token) {
                try {
                    // Decodificar el token JWT
                    const tokenPayload = JSON.parse(atob(token.split('.')[1]));
                    
                    // Obtener nombre y email del usuario
                    const username = tokenPayload['cognito:username'];
                    const email = tokenPayload.email;

                    // Actualizar elementos en el DOM
                    document.getElementById('username').textContent = username;
                    document.getElementById('mail').textContent = email;

                    // Mostrar el popup
                    document.getElementById('overlay').style.display = 'block';
                    document.getElementById('profile-popup').style.display = 'block';

                } catch (error) {
                    console.error('Error al obtener datos del usuario:', error);
                    alert('Error al obtener datos del usuario');
                }
            } else {
                console.log("No token in URL.");
            }
        };

        const logoutButton = document.getElementById("logout-btn");
        if (logoutButton) {
            logoutButton.addEventListener("click", function () {
                const cognitoLogoutUrl = `https://${domain}.auth.us-east-1.amazoncognito.com/logout?client_id=${user_pool_client_id}&logout_uri=https://${api_gateway_id}.execute-api.us-east-1.amazonaws.com/prod/redirect`;
                window.location.href = cognitoLogoutUrl;
            });
        }

        // Función para cerrar el popup
        const closePopupProfile = document.getElementById("closePopupProfile");
        if (closePopupProfile) {
            closePopupProfile.addEventListener("click", function () {
                document.getElementById('overlay').style.display = 'none';
                document.getElementById('profile-popup').style.display = 'none';
            });
        }
    }
}

async function upload() {
    const upload = document.getElementById("upload");
    if (upload) {
        upload.addEventListener("click", async function () {
            const isAdmin = await verificarPermisosAdmin();
            if (isAdmin) {
                console.log("Usuario autorizado");
                document.getElementById('overlay').style.display = 'block';
                document.getElementById('upload-popup').style.display = 'block';
            } else {
                console.log("Usuario no autorizado");
                alert('No tienes permisos para acceder a esta función');
            }
        });
    }

    // Función para cerrar el popup
    const closePopupUpload = document.getElementById("closePopupUpload");
    if (closePopupUpload) {
        closePopupUpload.addEventListener("click", function () {
            document.getElementById('overlay').style.display = 'none';
            document.getElementById('upload-popup').style.display = 'none';
        });
    }

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
            
            const cleanedCsvData = csvData
            .replace(/\r/g, '') // remover \r
            .replace(/"/g, '') // remover TODAS las comillas
            .split('\n') // dividir en líneas
            .filter(line => line.trim() !== '') // remover líneas vacías
            .map(line => {
                const columns = line.split(',');
                return columns.slice(1).join(','); // remover primera columna
            })
            .map((line, index) => {
                const columns = line.split(',');
                
                // Remover la primera columna (índice) solo de los registros
                const withoutIndex = columns.slice(0);
                
                // Asegurarse de que cada columna tenga un valor
                const processedColumns = withoutIndex.map(col => 
                    col.trim() === '' || col === 'NA' ? 'NA' : col
                );
                
                return processedColumns.join(',');
            })
            .join('\n'); // unir con \n

            console.log("Request body stringificado:", JSON.stringify(cleanedCsvData));

            await getToken()
            .then(token => {
                if (!token) {
                    console.error('No token available');
                    return;
                }
        
                $.ajax({
                    url: `https://${api_gateway_id}.execute-api.us-east-1.amazonaws.com/prod/upload`,
                    type: 'POST',
                    data: JSON.stringify(cleanedCsvData),
                    contentType: 'application/json',
                    headers: {
                        'Authorization': token,
                        'X-Amz-Date': new Date().toISOString()
                    },
                    xhrFields: {
                        withCredentials: true
                    },
                    crossDomain: true,
                    success: function (response) {
                        alert('Archivo cargado exitosamente');
                        document.getElementById('overlay').style.display = 'none';
                        document.getElementById('upload-popup').style.display = 'none';
                    },
                    error: function (xhr, status, error) {
                        alert("Error en la carga: " + error);
                        console.error('Error details:', {xhr, status, error});
                    }
                });
            })
            .catch(error => {
                console.error('Error obteniendo el token:', error);
            });
            
            // try {
                // const response = await fetch(`https://${api_gateway_id}.execute-api.us-east-1.amazonaws.com/prod/upload`, {
                // // const response = await fetch(`https://${api_gateway_id}.execute-api.us-east-1.amazonaws.com/prod/csv_to_dynamo`, {
                //     method: 'POST',
                //     credentials: 'include',
                //     headers: {
                //         'Authorization': 'Bearer ' + token,
                //         'Content-Type': 'application/json'
                //     },
                //     body: JSON.stringify({ data: csvData })
                // });
            
                // if (!response.ok) {
                //     throw new Error('Error al cargar el archivo CSV');
                // }

                // const result = await response.json();
                // console.log('Archivo CSV cargado exitosamente:', result);
                // alert('Archivo cargado exitosamente');

                // Cerrar el popup después de la carga
                // document.getElementById('overlay').style.display = 'none';
                // document.getElementById('uploadPopup').style.display = 'none';
            // } catch (error) {
            //     console.error('Error:', error);
            //     alert('Error al cargar el archivo CSV: ' + error.message);
            // }

        };

        reader.readAsText(file);
    };
}

async function optimization() {
    // Lambda Optimization
    document.getElementById('selectionForm').addEventListener('submit', async function(event) {
        event.preventDefault();

        const budget = document.getElementById('budget').value;
        const preference = document.querySelector('input[name="preference"]:checked').value;

        await getToken()
        .then(token => {
            if (!token) {
                alert("Debes iniciar sesión primero");
                console.error('No token available');
                return;
            }

            $.ajax({
                url: `https://${api_gateway_id}.execute-api.us-east-1.amazonaws.com/prod/optimization`,
                type: 'GET',
                data: {
                    presupuesto: budget,
                    tipo_uso: preference
                },
                headers: {
                    'Authorization': token,
                },
                xhrFields: {
                    withCredentials: true
                },
                crossDomain: true,
                success: function(data) {
                    console.log('Respuesta recibida:', data);
                    
                    let responseBody;
                    
                    if (data.body) {
                        try {
                            responseBody = JSON.parse(data.body);
                        } catch (e) {
                            console.error('Error al parsear data.body:', e);
                            const resultContainer = document.getElementById('result-container');
                            resultContainer.innerHTML = "<h3>Error al procesar la respuesta del servidor.</h3>";
                            return;
                        }
                    } else if (data.components) {
                        responseBody = data;
                    } else {
                        console.error('Respuesta no contiene "body" ni "components":', data);
                        const resultContainer = document.getElementById('result-container');
                        resultContainer.innerHTML = "<h3>Respuesta inválida del servidor.</h3>";
                        return;
                    }

                    if (responseBody.components && Array.isArray(responseBody.components)) {
                        const resultContainer = document.getElementById('result-container');
                        let html = "<h3>Recommended Components:</h3><ul>";

                        responseBody.components.forEach(item => {
                            html += `
                                <li>
                                    <strong>${capitalizeFirstLetter(item.partType)}:</strong> 
                                    <a href="${item.url}" target="_blank">${item.name}</a> - 
                                    $${item.precio.toFixed(2)}
                                </li>
                            `;
                        });

                        html += "</ul>";
                        resultContainer.innerHTML = html;
                    } else if (responseBody.error) {
                        console.error('Error desde Lambda:', responseBody.error);
                        const resultContainer = document.getElementById('result-container');
                        resultContainer.innerHTML = `<h3>Error:</h3><p>${responseBody.error}</p>`;
                    } else {
                        console.error('Respuesta inesperada:', data);
                        const resultContainer = document.getElementById('result-container');
                        resultContainer.innerHTML = "<h3>Respuesta inesperada del servidor.</h3>";
                    }
                },
                error: function(xhr, status, error) {
                    console.error('Error:', {
                        status: status,
                        statusText: xhr.statusText,
                        error: error,
                        response: xhr.responseText
                    });
                    const resultContainer = document.getElementById('result-container');
                    resultContainer.innerHTML = "<h3>Error al conectar con el servidor.</h3>";
                }
            });
        })
        .catch(error => {
            console.error('Error obteniendo el token:', error);
        });
    });

    // Función para capitalizar la primera letra de una cadena
    function capitalizeFirstLetter(string) {
        return string.charAt(0).toUpperCase() + string.slice(1);
    }

    const resetBtn = document.getElementById('reset-button');
    if (resetBtn) {
        resetBtn.addEventListener('click', function() {
            document.getElementById('selectionForm').reset();
            document.getElementById('result-container').innerHTML = "";
        });
    }
}

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
          api_gateway_id = config.api_gateway_id;

          init();
      })
      .catch(error => {
          console.error('There was a problem with the fetch operation:', error);
      });
}

async function init() {
    AWS.config.region = 'us-east-1';

    // Verificar permisos antes de mostrar el botón de upload
    const isAdmin = await verificarPermisosAdmin();
    const uploadBtn = document.getElementById("upload");
  
    if (uploadBtn) {
        if (!isAdmin) {
            document.getElementById("upload").style.display = 'none';
        } else {
            upload(); // Solo inicializar la funcionalidad de upload si es admin
        }
    }

    login();
    optimization();
}

window.addEventListener('load', () => {
    loadConfig();
});