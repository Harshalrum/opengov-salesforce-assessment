/**
 * @description    Invocable utility class used by Record-Triggered Flows
 *                 (specifically the "Quote to Asset" Flow) to convert raw
 *                 Salesforce fault messages into clean, user-readable text
 *                 that can be posted to Chatter or shown in a screen flow.
 *
 *                 Raw fault messages look like:
 *                   "FIELD_CUSTOM_VALIDATION_EXCEPTION, Warranty End Date
 *                    must be after Start Date: [End_Date__c]"
 *
 *                 Cleaned output:
 *                   "Warranty End Date must be after Start Date."
 *
 * @usage          Called from the Fault Path of a Create Records element.
 *
 * @author         Harshal Ramdham
 */
public with sharing class FlowErrorHandler {

    // Regex patterns stripped from raw fault messages, in the order they
    // appear in real Flow fault text.
    //
    // (?i) at the start of each pattern makes the match case-insensitive,
    // which protects us against future platform changes that adjust casing.
    //
    // Patterns are kept as static finals so the JIT compiler caches the
    // compiled Pattern objects (matters once we run on bulk records).

    // (1) The Flow platform's outer preamble. Salesforce wraps every fault
    //     message in "This error occurred when the flow tried to <verb>
    //     records: " — strip the whole sentence prefix up to and including
    //     the colon-space.
    private static final String FLOW_PREAMBLE_PATTERN =
        '(?i)This error occurred when the flow tried to [A-Za-z ]+ records:\\s*';

    // (2) The Flow platform's trailing help link. Looks like:
    //     " You can look up ExceptionCode values in the <a href='...'>SOAP
    //      API Developer Guide</a>."
    //     We strip from " You can look up" all the way to the end of string.
    private static final String FLOW_HELP_LINK_PATTERN =
        '(?is)\\s*You can look up.*$';

    // (3) Any HTML tag — belt-and-braces for other anchor tags or <br/>.
    private static final String HTML_TAG_PATTERN = '<[^>]+>';

    // (4) Exception tags like FIELD_CUSTOM_VALIDATION_EXCEPTION followed by
    //     either a comma or colon (Salesforce uses both depending on
    //     context). Order: longer tags first so they win the alternation.
    private static final String EXCEPTION_TAG_PATTERN =
        '(?i)(FIELD_CUSTOM_VALIDATION_EXCEPTION|FIELD_INTEGRITY_EXCEPTION|REQUIRED_FIELD_MISSING|INVALID_FIELD_FOR_INSERT_UPDATE|DUPLICATE_VALUE|INSUFFICIENT_ACCESS_OR_READONLY|STORAGE_LIMIT_EXCEEDED|System\\.DmlException|System\\.QueryException|System\\.LimitException|System\\.NullPointerException)[:,]\\s*';

    // (5) Field references in square brackets like "[End_Date__c]".
    private static final String FIELD_BRACKET_PATTERN = '\\s*\\[[^\\]]*\\]\\s*';

    // (6) "execution of <Trigger> caused by:" preamble.
    private static final String EXEC_AT_ROW_PATTERN = 'execution of [A-Za-z]+ caused by:';

    // (7) Apex stack-trace lines (Class.Foo.bar: line 5, column 1).
    private static final String CLASS_TRACE_PATTERN = 'Class\\.[A-Za-z0-9_.]+:.*';

    /**
     * @description Wrapper for invocable inputs. We use an explicit wrapper
     *              (rather than a flat List<String>) so the Flow Builder UI
     *              presents a single clear "Raw Fault Messages" input.
     */
    public class Request {
        @InvocableVariable(
            label='Raw Fault Messages'
            description='List of raw fault messages from a Flow fault path.'
            required=true)
        public List<String> rawMessages;
    }

    /**
     * @description Wrapper for invocable outputs.
     *
     *              Two outputs are exposed for Flow convenience:
     *               - cleanedMessages: List<String>, parallel to the input list
     *                 (use when the Flow passed in multiple raw messages).
     *               - cleanedMessage:  String, the first / only cleaned message
     *                 (use when the Flow passed in exactly one raw message,
     *                 which is the typical Record-Triggered Flow case).
     *
     *              Having both means the Flow author never has to index into
     *              a collection — they just reference the right field.
     */
    public class Response {
        @InvocableVariable(label='Cleaned Messages (List)'
            description='Parallel list of cleaned messages, one per input.')
        public List<String> cleanedMessages;

        @InvocableVariable(label='Cleaned Message (First)'
            description='Convenience scalar: the first cleaned message. Use this in a fault path with a single raw message.')
        public String cleanedMessage;
    }

    /**
     * @description The Invocable method itself. Salesforce requires invocable
     *              methods that accept lists, so the Flow can call them in
     *              bulk if needed.
     *
     * @param  requests List of Request wrappers (typically size 1 from a Flow).
     * @return List of Response wrappers, one per input request.
     */
    @InvocableMethod(
        label='Clean Flow Fault Messages'
        description='Strips system tags and IDs from Flow fault messages to produce a user-friendly string.'
        category='Error Handling')
    public static List<Response> cleanMessages(List<Request> requests) {

        List<Response> responses = new List<Response>();

        // Guard against null/empty input - Flows occasionally pass null.
        if (requests == null || requests.isEmpty()) {
            return responses;
        }

        for (Request req : requests) {
            Response res = new Response();
            res.cleanedMessages = new List<String>();

            if (req != null && req.rawMessages != null) {
                for (String raw : req.rawMessages) {
                    res.cleanedMessages.add(cleanSingleMessage(raw));
                }
            }

            // Convenience scalar: first cleaned message (or empty string if none).
            res.cleanedMessage = res.cleanedMessages.isEmpty()
                ? ''
                : res.cleanedMessages[0];

            responses.add(res);
        }
        return responses;
    }

    /**
     * @description Cleans a single raw fault message. Public-static so it
     *              can be unit tested directly without constructing Request
     *              wrappers.
     */
    @TestVisible
    private static String cleanSingleMessage(String raw) {
        if (String.isBlank(raw)) {
            return 'An unknown error occurred. Please contact your administrator.';
        }

        String cleaned = raw;

        // Phase 1 — strip the Flow platform's outer wrappers first.
        cleaned = cleaned.replaceAll(FLOW_PREAMBLE_PATTERN, '');
        cleaned = cleaned.replaceAll(FLOW_HELP_LINK_PATTERN, '');
        cleaned = cleaned.replaceAll(HTML_TAG_PATTERN, '');

        // Phase 2 — strip Salesforce-specific exception tags and references.
        cleaned = cleaned.replaceAll(EXCEPTION_TAG_PATTERN, '');
        cleaned = cleaned.replaceAll(FIELD_BRACKET_PATTERN, ' ');
        cleaned = cleaned.replaceAll(EXEC_AT_ROW_PATTERN, '');
        cleaned = cleaned.replaceAll(CLASS_TRACE_PATTERN, '');

        // Phase 3 — strip 15/18-char Salesforce IDs (defensive).
        cleaned = cleaned.replaceAll('\\b[a-zA-Z0-9]{15,18}\\b', '');

        // Phase 4 — cosmetic cleanup.
        // Collapse repeated punctuation like ".." or ". ." into a single period.
        cleaned = cleaned.replaceAll('\\.\\s*\\.', '.');
        // Collapse multiple whitespace, trim leading/trailing space.
        cleaned = cleaned.replaceAll('\\s+', ' ').trim();
        // Remove any stray leading punctuation left behind (e.g. ": foo" → "foo").
        cleaned = cleaned.replaceAll('^[:,.\\s]+', '');

        // Ensure the message ends with proper punctuation.
        if (String.isNotBlank(cleaned) && !cleaned.endsWith('.')
            && !cleaned.endsWith('!') && !cleaned.endsWith('?')) {
            cleaned += '.';
        }

        return String.isBlank(cleaned)
            ? 'An unknown error occurred. Please contact your administrator.'
            : cleaned;
    }
}