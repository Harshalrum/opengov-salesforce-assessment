import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';

export default class AssetCreationToast extends LightningElement {
    @api recordId; // Quote Id, injected by the Lightning record page

    channelName = '/event/Asset_Creation_Result__e';
    subscription = {};

    connectedCallback() {
        this.registerErrorListener();
        this.subscribeToChannel();
    }

    disconnectedCallback() {
        this.unsubscribeFromChannel();
    }

    subscribeToChannel() {
        // -1 = receive only new events from now on (don't replay history)
        subscribe(this.channelName, -1, (event) => {
            this.handleEvent(event);
        })
            .then((response) => {
                this.subscription = response;
                // eslint-disable-next-line no-console
                console.log('Subscribed to', this.channelName);
            })
            .catch((error) => {
                // eslint-disable-next-line no-console
                console.error('Subscription error', error);
            });
    }

    unsubscribeFromChannel() {
        if (this.subscription && this.subscription.id) {
            unsubscribe(this.subscription, () => {
                // eslint-disable-next-line no-console
                console.log('Unsubscribed from', this.channelName);
            });
        }
    }

    registerErrorListener() {
        onError((error) => {
            // eslint-disable-next-line no-console
            console.error('EMP API error', JSON.stringify(error));
        });
    }

    handleEvent(event) {
        const payload = event?.data?.payload;
        if (!payload) {
            return;
        }

        const eventQuoteId = payload.Quote_Id__c;
        const status = payload.Status__c;
        const message = payload.Message__c;
        const assetCount = payload.Asset_Count__c;

        // Only react to events for the Quote the user is currently viewing.
        // Compare on the 15-char prefix so we don't fail on 15 vs 18 char Ids.
        if (
            !this.recordId ||
            !eventQuoteId ||
            this.recordId.substring(0, 15) !== eventQuoteId.substring(0, 15)
        ) {
            return;
        }

        let title;
        let variant;
        let displayMessage = message;

        if (status === 'Success') {
            title = 'Assets Created';
            variant = 'success';
            displayMessage = `${assetCount} asset(s) created from this Contracted Quote.`;
        } else if (status === 'NoHardware') {
            title = 'No Assets Created';
            variant = 'info';
        } else if (status === 'Error') {
            title = 'Asset Creation Failed';
            variant = 'error';
        } else {
            title = 'Asset Creation Result';
            variant = 'info';
        }

        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message: displayMessage,
                variant,
                mode: variant === 'error' ? 'sticky' : 'dismissable'
            })
        );
    }
}