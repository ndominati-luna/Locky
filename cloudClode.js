var getLanguageObjectId = function (language) {
  if (language == "en") {
    return "4JaeT4HJ7N";
  } else if (language == "fr") {
    return "EKsqu6j7ld";
  // } else if (language == "de") {
  //   return "gsaBjI7hDZ";
  // } else if (language == "es") {
  //   return "to0xSEzjGW";
  // } else if (language == "it") {
  //   return "pzWhLXvjqD";
  // } else if (language == "ja") {
  //   return "aFTlHdPIBI";
  // } else if (language == "ko") {
  //   return "lUswLGJunX";
  // } else if (language == "pt") {
  //   return "l56AU86WqR";
  // } else if (language == "ru") {
  //   return "SK5pObDUJN";
  // } else if (language == "zh") {
  //   return "bRNHOH5RZm";
  } else {
    return "4JaeT4HJ7N";
  }
}

Parse.Cloud.define("sendDownloadEmailToReceiver", function(request, response) {
  var query = new Parse.Query('Localization');

  return query.get(getLanguageObjectId(request.params.language), {
    success:function(localized) {
      if (request.params.system == "Mac") {
        var subject = localized.get('macMailSubject');
        var mailContent = localized.get('macMailContent');
      } else {
        var subject = localized.get('iMailSubject');
        var mailContent = localized.get('iMailContent');
      }
      return Parse.Cloud.httpRequest({
        method: 'POST',
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
        },
        url: 'https://mandrillapp.com/api/1.0/messages/send.json',
        body:{
          key: "PXLt5wTUFPvq-U23weHTzA",
          message: {
            html: mailContent,
            subject: subject,
            from_email: "no_reply@lunabee.com",
            from_name: "Team Lunabee",
            to: [{
              email: request.params.mail
            }]},
            async: true
          },

          success: function(httpResponse) {
            response.success("email sent");
          },
          error: function(httpResponse) {
            response.error(httpResponse);
          }

        });
      },
      error: function(error) {
        response.error("language not found");
      }});
    });
