// exports.handler = (event, context, callback) => {
//     const response = {
//      statusCode: 302,
//      headers: {
//        Location: process.env.REDIRECT_URL
//      }
//    };
 
//    callback(null, response);
//  };
 
exports.handler = (event, context, callback) => {
  const queryParams = event.queryStringParameters || {};
  const path = event.path || '';

  let redirectUrl = process.env.REDIRECT_URL; // URL por defecto para callback
  if (queryParams.code) {
      // Si viene un 'code', es un callback de login exitoso
      console.log('Handling login callback');
  } else if (path.includes('logout')) {
      // Si el path tiene 'logout', redirigir a la URL de logout
      console.log('Handling logout');
      redirectUrl = process.env.LOGOUT_REDIRECT_URL; // URL específica para logout
  }

  const response = {
      statusCode: 302,
      headers: {
          Location: redirectUrl
      }
  };

  callback(null, response);
};
