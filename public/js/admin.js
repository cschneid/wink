// Delete Links
$(document).ready(function() {
	$("a[rel*='delete']").click(function(event) {
		var $anchor = $(this);

		$.ajax({
			type: 'DELETE',
			url: $anchor.attr('href'),
			success: function (r) {
				$anchor.parents('.container:first').fadeOut();
			},
			error: function(r,text) {
				alert("Could not delete: "+$anchor.attr('href')+"\n\n"+text);
			}
		});

		event.preventDefault();
	});
});

// Comment Editing
$(document).ready(function() {

	$('li.comment a.edit').click(function(event) {
		$(this).parents('li:first').
			find('form,.body').toggle();
		event.preventDefault();
	});

	$('li.comment form').submit( function(event) {
		var data = $(this).find('textarea').val();
		var body = $(this).parents('li:first').find('.body');
		var form = this;

		$.put(form.action, data, 'text/plain', function() {
			body.load(form.action);
			$(form).hide();
			$(body).fadeIn();
		});

		event.preventDefault();
	});

});

// vim: ft=javascript sw=4 ts=4 sts=4 noexpandtab
