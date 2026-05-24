import { LightningElement, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getMyServiceRequests from '@salesforce/apex/CommunityPortalController.getMyServiceRequests';

const COLUMNS = [
    { label: 'Subject',       fieldName: 'subject',      type: 'text' },
    { label: 'Priority',      fieldName: 'priority',     type: 'text',
      cellAttributes: { class: { fieldName: 'priorityClass' } } },
    { label: 'Status',        fieldName: 'status',       type: 'text' },
    { label: 'Due Date',      fieldName: 'activityDate', type: 'date-local' },
    { label: 'Assigned To',   fieldName: 'ownerName',    type: 'text' },
    { label: 'Description',   fieldName: 'description',  type: 'text',
      wrapText: true }
];

export default class CustomerServiceRequests extends LightningElement {
    @track tasks = [];
    @track error;
    isLoading = true;
    columns = COLUMNS;
    wiredTasksResult;

    @wire(getMyServiceRequests)
    wiredTasks(result) {
        this.wiredTasksResult = result;
        this.isLoading = false;
        if (result.data) {
            this.tasks = result.data.map(t => this.decorate(t));
            this.error = undefined;
        } else if (result.error) {
            this.tasks = [];
            this.error = this.reduceError(result.error);
        }
    }

    decorate(t) {
        return {
            ...t,
            priorityClass: t.priority === 'High'   ? 'slds-text-color_destructive' :
                           t.priority === 'Normal' ? 'slds-text-color_default'     :
                                                     'slds-text-color_weak'
        };
    }

    get isEmpty() {
        return !this.isLoading && !this.error && this.tasks.length === 0;
    }
    get hasData() {
        return !this.isLoading && !this.error && this.tasks.length > 0;
    }
    get taskCount() {
        return this.tasks.length;
    }

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this.wiredTasksResult).finally(() => { this.isLoading = false; });
    }

    reduceError(error) {
        if (Array.isArray(error?.body)) {
            return error.body.map(e => e.message).join(', ');
        }
        return error?.body?.message || error?.message || 'Unknown error';
    }
}