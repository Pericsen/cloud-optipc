let domain, user_pool_client_id, user_pool_id, api_gateway_id;
let tokenInMemory = null;

// Función para mostrar las alternativas en el contenedor de resultados
function mostrarAlternativas(alternatives, index) {
    // Intentar buscar el contenedor de alternativas
    let alternativesContainer = document.getElementById('alternatives-container');

    // Si el contenedor no existe, crearlo
    if (!alternativesContainer) {
        alternativesContainer = document.createElement('div');
        alternativesContainer.id = 'alternatives-container';
        document.body.appendChild(alternativesContainer); // Puedes agregarlo en el lugar adecuado en el DOM
    }

    // Limpiar el contenido previo
    alternativesContainer.innerHTML = '';

    if (alternatives.length === 0) {
        alternativesContainer.innerHTML = '<p>No se encontraron alternativas en el rango de precio especificado.</p>';
        return;
    }

    // Generar el HTML para mostrar las alternativas
    let html = "<h3>Alternativas de Componentes:</h3><ul>";

    alternatives.forEach((alternative, altIndex) => {
        html += `
            <li>
                <strong>${alternative.name}:</strong> $${parseFloat(alternative.precio_ficticio).toFixed(2)}
                <button onclick="elegirComponente(${index}, ${altIndex})">Elegir</button>
            </li>
        `;
    });

    html += "</ul>";
    alternativesContainer.innerHTML = html;

    // Guardar alternativas para usarlas mas adelante
    window.alternativas = alternatives;
}

function elegirComponente(originalIndex, alternativeIndex) {
    // Obtener el componente alternativo seleccionado
    const alternative = window.alternativas[alternativeIndex];
    if (!alternative) {
        console.error('No se encontró el componente alternativo seleccionado');
        return;
    }

    // Actualizar el componente en el listado original
    const resultContainer = document.getElementById('result-container');
    let componentItems = resultContainer.getElementsByTagName('li');

    if (originalIndex < 0 || originalIndex >= componentItems.length) {
        console.error('Índice de componente original no válido');
        return;
    }

    // Reemplazar el contenido del componente con el nuevo componente seleccionado
    const updatedHtml = `
        <strong>${capitalizeFirstLetter(alternative.partType)}:</strong> 
        <span>${alternative.name} - $${parseFloat(alternative.precio_ficticio).toFixed(2)}</span>
        <button onclick="cambiarComponente('${alternative.partType}', ${alternative.precio_ficticio}, ${originalIndex})">Cambiar Componente</button>
    `;

    componentItems[originalIndex].innerHTML = updatedHtml;

    const alternativesContainer = document.getElementById('alternatives-container');
    if (alternativesContainer) {
        alternativesContainer.innerHTML = ''; // Limpiar el contenido del contenedor
        alternativesContainer.style.display = 'none'; // Ocultar el contenedor
    }
}

// Función para capitalizar la primera letra de una cadena
function capitalizeFirstLetter(string) {
    return string.charAt(0).toUpperCase() + string.slice(1);
}

function resetForm() {
    document.getElementById('selectionForm').reset();
    document.getElementById('result-container').innerHTML = "";
}


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
        const layerCarga = document.getElementById('layer_carga');
        const loadingIcon = document.getElementById('loadingIcon');

        if (!file) {
            alert("Por favor, selecciona un archivo CSV.");
            return;
        }

        const reader = new FileReader();
        reader.onload = async function(event) {
            const csvData = event.target.result;

            layerCarga.style.display = 'flex';
            loadingIcon.style.display = 'flex';

            try {
                const cleanedCsvData = csvData
                .replace(/\r/g, '') // remover \r
                .replace(/"/g, '') // remover TODAS las comillas
                .split('\n') // dividir en líneas
                .filter(line => line.trim() !== '') // remover líneas vacías
                .map((line, index) => {
                    const columns = line.split(',');
                    
                    // Remover la primera columna (índice) solo de los registros
                    // const withoutIndex = columns.slice(0);
                    
                    // Asegurarse de que cada columna tenga un valor
                    const processedColumns = columns.map(col => 
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
                    })
            } catch (error) {
                console.error('Error:', error);
                alert('Error durante la carga del archivo: ' + error.message);
            } finally {
                layerCarga.style.display = 'none';
                loadingIcon.style.display = 'none';
            }
        };

        reader.readAsText(file);
    };
}

async function optimization() {
    const token = await getToken();
    const headers = {
        'Content-Type': 'application/json',
    };
    if (token){
        headers['Authorization'] = `Bearer ${token}`;
    }
    
    // Lambda Optimization
    document.getElementById('selectionForm').addEventListener('submit', function(event) {
        event.preventDefault();

        const budget = document.getElementById('budget').value;
        const preference = document.querySelector('input[name="preference"]:checked').value;

        fetch(`https://${api_gateway_id}.execute-api.us-east-1.amazonaws.com/prod/optimization`, {
            method: 'POST',
            headers: headers,
            body: JSON.stringify({
                presupuesto: budget,
                tipo_uso: preference
            })
        })
        .then(response => {
            if (!response.ok) {
                throw new Error('Network response was not ok');
            }
            return response.json();
        })
        .then(data => {
            console.log('Respuesta recibida:', data); // Log para depuración

            let responseBody;

            if (data.body) {
                try {
                    responseBody = JSON.parse(data.body);
                } catch (e) {
                    console.error('Error al parsear data.body:', e);
                    document.getElementById('result-container').innerHTML = "<h3>Error al procesar la respuesta del servidor.</h3>";
                    return;
                }
            } else if (data.components) {
                responseBody = data;
            } else {
                console.error('Respuesta no contiene "body" ni "components":', data);
                document.getElementById('result-container').innerHTML = "<h3>Respuesta inválida del servidor.</h3>";
                return;
            }

            // Verificar si 'components' está presente y es un arreglo
            if (responseBody.components && Array.isArray(responseBody.components)) {
                const resultContainer = document.getElementById('result-container');
                let html = "<h3>Recommended Components:</h3><ul>";

                responseBody.components.forEach((item, index) => {
                    html += `
                        <li>
                            <strong>${capitalizeFirstLetter(item.partType)}:</strong> 
                            <span>${item.name} - $${item.precio.toFixed(2)}</span>
                            <button onclick="cambiarComponente('${item.partType}', ${item.precio}, ${index})">Cambiar Componente</button>
                        </li>
                    `;
                });

                html += "</ul>";
                resultContainer.innerHTML = html;
            } else if (responseBody.error) {
                console.error('Error desde Lambda:', responseBody.error);
                document.getElementById('result-container').innerHTML = `<h3>Error:</h3><p>${responseBody.error}</p>`;
            } else {
                console.error('Respuesta inesperada:', data);
                document.getElementById('result-container').innerHTML = "<h3>Respuesta inesperada del servidor.</h3>";
            }
        })
        .catch(error => {
            console.error('Error:', error);
            document.getElementById('result-container').innerHTML = "<h3>Error al conectar con el servidor.</h3>";
        });
    });
}

// Función para cambiar el componente y mostrar alternativas
async function cambiarComponente(tipoComponente, precioFicticio, index) {
    console.log('Solicitando alternativas para:', tipoComponente, 'con precio:', precioFicticio);

    try {
        const response = await fetch(`https://${api_gateway_id}.execute-api.us-east-1.amazonaws.com/prod/modify`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                tipo_componente: tipoComponente,
                precio_ficticio: precioFicticio,
            }),
        });

        console.log('Respuesta recibida del servidor:', response);

        if (!response.ok) {
            throw new Error('Error al obtener alternativas del servidor');
        }

        const data = await response.json();
        console.log('Datos obtenidos:', data);
        mostrarAlternativas(data.alternatives, index);
        
        const alternativesContainer = document.getElementById('alternatives-container');
        if (alternativesContainer) {
            alternativesContainer.style.display = 'block';
        }

    } catch (error) {
        console.error('Error al cambiar componente:', error);
        const alternativesContainer = document.getElementById('alternatives-container');
        alternativesContainer.innerHTML = `<p>Error al obtener alternativas: ${error.message}</p>`;
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
      // cambiarComponente();
  }
  
  window.addEventListener('load', () => {
      loadConfig();
  });