exports.handler = (event, context, callback) => {
    const queryParams = event.queryStringParameters || {};
    const path = event.path || '';
    
    let redirectUrl;
    
    if (queryParams.code) {
        console.log('Handling login callback');
        // Determinar si es admin o usuario normal basado en la URL actual
        redirectUrl = process.env.REDIRECT_ADMIN_URL;
        redirectUrl = `${redirectUrl}?code=${queryParams.code}`;
    } else {
        console.log('Handling logout');
        redirectUrl = process.env.LOGOUT_REDIRECT_URL;
    }

    const response = {
        statusCode: 302,
        headers: {
            Location: redirectUrl
        }
    };

    callback(null, response);
};