exports.handler = (event, context, callback) => {
    const queryParams = event.queryStringParameters || {};
    const path = event.path || '';
    
    let redirectUrl;
    
    if (queryParams.code) {
        console.log('Handling login callback');
        // Determinar si es admin o usuario normal basado en la URL actual
        redirectUrl = process.env.REDIRECT_ADMIN_URL;
        redirectUrl = `${redirectUrl}?code=${queryParams.code}`;
    } else if (path.includes('logout')) {
        console.log('Handling logout');
        redirectUrl = process.env.LOGOUT_REDIRECT_URL;
    } else {
        // Construir URL de login de Cognito
        const domain = `${process.env.USER_POOL_ID.split('_')[0]}.auth.us-east-1.amazoncognito.com`;
        redirectUrl = `https://${domain}/login?client_id=${process.env.CLIENT_ID}&response_type=code&scope=email+openid+profile&redirect_uri=${encodeURIComponent(event.headers.Host + event.path)}`;
    }

    const response = {
        statusCode: 302,
        headers: {
            Location: redirectUrl
        }
    };

    callback(null, response);
};