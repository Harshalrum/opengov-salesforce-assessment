/**
 * @description Unit tests for FlowErrorHandler. Covers happy path, edge cases
 *              (null, blank, no exception tags), and a representative sample
 *              of real-world fault message patterns.
 */
@IsTest
private class FlowErrorHandlerTest {

    @IsTest
    static void cleansFieldCustomValidationException() {
        List<FlowErrorHandler.Request> reqs = new List<FlowErrorHandler.Request>();
        FlowErrorHandler.Request r = new FlowErrorHandler.Request();
        r.rawMessages = new List<String>{
            'FIELD_CUSTOM_VALIDATION_EXCEPTION, Warranty End Date must be after Start Date: [End_Date__c]'
        };
        reqs.add(r);

        Test.startTest();
        List<FlowErrorHandler.Response> resp = FlowErrorHandler.cleanMessages(reqs);
        Test.stopTest();

        System.assertEquals(1, resp.size(), 'Should return one response per request');
        String cleaned = resp[0].cleanedMessages[0];
        System.assert(!cleaned.contains('FIELD_CUSTOM_VALIDATION_EXCEPTION'),
            'Exception tag should be stripped: ' + cleaned);
        System.assert(!cleaned.contains('['), 'Field brackets should be stripped: ' + cleaned);
        System.assert(cleaned.contains('Warranty End Date must be after Start Date'),
            'Core message must be preserved: ' + cleaned);
    }

    @IsTest
    static void cleansDmlExceptionWithStackTrace() {
        List<FlowErrorHandler.Request> reqs = new List<FlowErrorHandler.Request>();
        FlowErrorHandler.Request r = new FlowErrorHandler.Request();
        r.rawMessages = new List<String>{
            'System.DmlException: Insert failed. First exception on row 0; first error: ' +
            'REQUIRED_FIELD_MISSING, Required fields are missing: [Name] ' +
            'Class.AssetService.createKickoffTasks: line 88, column 1'
        };
        reqs.add(r);

        List<FlowErrorHandler.Response> resp = FlowErrorHandler.cleanMessages(reqs);
        String cleaned = resp[0].cleanedMessages[0];
        System.assert(!cleaned.contains('System.DmlException'), 'DML tag should be stripped');
        System.assert(!cleaned.contains('Class.'), 'Stack trace should be stripped');
    }

    @IsTest
    static void handlesNullAndEmptyGracefully() {
        // null list of requests
        System.assertEquals(0, FlowErrorHandler.cleanMessages(null).size());
        // empty list
        System.assertEquals(0, FlowErrorHandler.cleanMessages(new List<FlowErrorHandler.Request>()).size());
        // request with null rawMessages
        FlowErrorHandler.Request r = new FlowErrorHandler.Request();
        r.rawMessages = null;
        List<FlowErrorHandler.Response> resp =
            FlowErrorHandler.cleanMessages(new List<FlowErrorHandler.Request>{ r });
        System.assertEquals(1, resp.size());
        System.assertEquals(0, resp[0].cleanedMessages.size());
    }

    @IsTest
    static void blankMessageReturnsGenericFallback() {
        String cleaned = FlowErrorHandler.cleanSingleMessage('');
        System.assert(cleaned.contains('unknown error'), 'Blank input should fall back to generic msg');
    }

    @IsTest
    static void bulkInputDoesNotHitGovernorLimits() {
        List<FlowErrorHandler.Request> reqs = new List<FlowErrorHandler.Request>();
        FlowErrorHandler.Request r = new FlowErrorHandler.Request();
        r.rawMessages = new List<String>();
        for (Integer i = 0; i < 200; i++) {
            r.rawMessages.add('FIELD_CUSTOM_VALIDATION_EXCEPTION, Some error ' + i + ': [Field__c]');
        }
        reqs.add(r);

        Test.startTest();
        List<FlowErrorHandler.Response> resp = FlowErrorHandler.cleanMessages(reqs);
        Test.stopTest();

        System.assertEquals(200, resp[0].cleanedMessages.size(),
            'All 200 messages should be cleaned');
    }

    @IsTest
    static void scalarConvenienceFieldEqualsFirstListItem() {
        FlowErrorHandler.Request r = new FlowErrorHandler.Request();
        r.rawMessages = new List<String>{
            'FIELD_CUSTOM_VALIDATION_EXCEPTION, First error: [F__c]',
            'FIELD_CUSTOM_VALIDATION_EXCEPTION, Second error: [G__c]'
        };
        List<FlowErrorHandler.Response> resp =
            FlowErrorHandler.cleanMessages(new List<FlowErrorHandler.Request>{ r });

        System.assertEquals(2, resp[0].cleanedMessages.size());
        System.assertEquals(resp[0].cleanedMessages[0], resp[0].cleanedMessage,
            'Scalar output should mirror the first list entry for Flow convenience');
        System.assert(resp[0].cleanedMessage.contains('First error'),
            'Scalar should hold the first cleaned message');
    }

    @IsTest
    static void scalarIsEmptyStringWhenNoMessagesProvided() {
        FlowErrorHandler.Request r = new FlowErrorHandler.Request();
        r.rawMessages = new List<String>();
        List<FlowErrorHandler.Response> resp =
            FlowErrorHandler.cleanMessages(new List<FlowErrorHandler.Request>{ r });
        System.assertEquals('', resp[0].cleanedMessage,
            'Scalar should be empty string when no input messages');
    }

    /**
     * @description Real-world Record-Triggered Flow fault text observed in
     *              production: outer "This error occurred when the flow..."
     *              preamble, FIELD_CUSTOM_VALIDATION_EXCEPTION with a colon
     *              (not comma), and the trailing "You can look up..." HTML
     *              help link. The cleaner should reduce this to just the
     *              human-meaningful core message.
     */
    @IsTest
    static void cleansFullFlowPlatformFaultText() {
        String raw =
            'This error occurred when the flow tried to create records: ' +
            'FIELD_CUSTOM_VALIDATION_EXCEPTION: Asset Name is required to be longer ' +
            '(this is a forced demo failure).. ' +
            'You can look up ExceptionCode values in the ' +
            '<a href=\'https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_calls_concepts_core_data_objects.htm#\'>' +
            'SOAP API Developer Guide</a>.';

        String cleaned = FlowErrorHandler.cleanSingleMessage(raw);

        System.assert(!cleaned.contains('This error occurred when the flow'),
            'Platform preamble must be stripped: ' + cleaned);
        System.assert(!cleaned.contains('FIELD_CUSTOM_VALIDATION_EXCEPTION'),
            'Exception tag must be stripped: ' + cleaned);
        System.assert(!cleaned.contains('You can look up'),
            'Trailing help link sentence must be stripped: ' + cleaned);
        System.assert(!cleaned.contains('<a'),
            'HTML tags must be stripped: ' + cleaned);
        System.assert(!cleaned.contains('..'),
            'Double periods must be normalized: ' + cleaned);
        System.assertEquals(
            'Asset Name is required to be longer (this is a forced demo failure).',
            cleaned,
            'Final cleaned text should be the core validation message only');
    }

    @IsTest
    static void cleansFlowUpdateAndDeleteVerbVariants() {
        // The platform uses "create", "update", "delete" verbs in the preamble.
        // Our regex matches [A-Za-z ]+ so all three should work.
        String rawUpdate = 'This error occurred when the flow tried to update records: ' +
            'FIELD_CUSTOM_VALIDATION_EXCEPTION: Account Owner must be set.';
        String rawDelete = 'This error occurred when the flow tried to delete records: ' +
            'INSUFFICIENT_ACCESS_OR_READONLY: insufficient access rights on object id.';

        String cleanedU = FlowErrorHandler.cleanSingleMessage(rawUpdate);
        String cleanedD = FlowErrorHandler.cleanSingleMessage(rawDelete);

        System.assert(!cleanedU.contains('This error occurred'),
            'Update-verb preamble must be stripped');
        System.assert(!cleanedD.contains('This error occurred'),
            'Delete-verb preamble must be stripped');
        System.assert(cleanedU.contains('Account Owner'),
            'Core message must survive');
        System.assert(cleanedD.contains('insufficient access'),
            'Core message must survive');
    }
}