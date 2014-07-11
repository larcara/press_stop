var  api_key="TTU8rKwDFEN4uL4iuyO9wlNDTJE78kXR";


var bus_stops=[
];

function authenticate(callback, err) {
	$.xmlrpc({
    url: 'http://muovi.roma.it/ws/xml/autenticazione/1',
    methodName: 'autenticazione.Accedi',
    crossDomain: true,
    headers : {"Access-Control-Allow-Origin":"*"},//params: [api_key, 1, 4.6, true, [1, 2, 3], {name: 'value'}],
    params: [api_key, ""],
    success: function(response, status, jqXHR) {  },
    error: function(jqXHR, status, error) {  }
});
};