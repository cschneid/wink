
/* PUT/DELETE Extensions for jQuery
---------------------------------------------------------------------------*/

jQuery.extend({


	// Perform a PUT request on the resource specified. The data argument
	// is sent in the request body (without alteration) and the 
	// contentType is sent in the "Content-Type" header. If no contentType
	// is specified, "text/plain" is assumed.
	put: function( url, data, contentType, callback ) {
		if ( jQuery.isFunction(contentType) ) {
			callback = contentType;
			contentType = 'text/plain';
		}

		return jQuery.ajax({
			type: 'PUT',
			url: url,
			data: data,
			contentType: contentType,
			processData: false,
			dataType: 'text',
			success: callback
		});
	},


	// Perform a DELETE request on the resource specified and execute 
	// callback when response is received and successful.
	del: function( url, callback ) {
		return jQuery.ajax({
			type: 'DELETE',
			url: url,
			success: callback
		});
	},


	// Import another script from the URL provided and execute callback 
	// when complete. This is identical to jQuery.getScript() with the 
	// exception that caching is enabled. 
	require: function( url, callback ) {
		return jQuery.ajax({
			type: 'GET',
			url: url,
			success: callback,
			dataType: 'script',
			data: null,
			cache: true
		});
	}

});


/* Code Syntax Highlighting / Prettification
---------------------------------------------------------------------------*/

$(document).ready(function() {

	// add pretty printing to all <pre><code></code></pre> blocks ...
	var prettify = false;
	$("pre code").parent().each(function() {
		$(this).addClass('prettyprint');
		prettify = true;
	});

	// if any code blocks were found, bring in the prettifier ...
	if ( prettify ) {
		$.require("/js/prettify.js", function() {
			PR_TAB_WIDTH = 4;
			prettyPrint();
		});
	}

});

// vim: ts=4 sw=4 sts=0 noexpandtab
