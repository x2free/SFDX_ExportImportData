String strVersion = '54.0';
String strJobId = '7500t000005MXDM';
String strBatchId = '7510t000006VrYg';

String strBaseUrl = Url.getSalesforceBaseUrl().toExternalForm();

String strEndpoint = strBaseUrl + '/services/async/' + strVersion + '/job/' + strJobId + '/batch/' + strBatchId + '/result';

Http http = new Http();
HttpRequest req = new HttpRequest();
req.setMethod('GET');
// req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
req.setHeader('X-SFDC-Session', UserInfo.getSessionId());
req.setTimeout(6000);

req.setEndpoint(strEndpoint);
HttpResponse rep = http.send(req);

if (rep.getStatusCode() == 200) {
    System.debug(LoggingLevel.Info, 'Result - Start -:\n' + rep.getBody());
	System.debug(LoggingLevel.Info, 'Result - End -');
} else {
	System.debug(LoggingLevel.INFO, '*** response: ' + rep.getBody());
}

