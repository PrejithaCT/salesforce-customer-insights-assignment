public with sharing class CustomerInsightsController {

    //wrapper to get activities 
    public class ActivityWrapper {
        @AuraEnabled public String key;
        @AuraEnabled public String source;
        @AuraEnabled public String type;
        @AuraEnabled public String subject;
        @AuraEnabled public Date activityDate;
        @AuraEnabled public String status;
        @AuraEnabled public String productCategory;
    }
    //wrapper to return the results of engagement ,intent
    public class CustomerInsightWrapper {
        @AuraEnabled public String customerId;
        @AuraEnabled public String name;
        @AuraEnabled public String email;
        @AuraEnabled public String phone;
        @AuraEnabled public Integer engagementScore;
        @AuraEnabled public String intentLevel;
        @AuraEnabled public String productInterest;
        @AuraEnabled public List<ActivityWrapper> recentActivities;
    }

    public class ReccosWrapper {
        @AuraEnabled public String recommendation;
        @AuraEnabled public String reason;
    }
      //method returning all the customer insights data
    @AuraEnabled(cacheable=true)
    public static CustomerInsightWrapper getCustomerInsights(String customerId) {
        if (String.isBlank(customerId)) {
            throw new AuraHandledException('Customer Id is required.');
        }

        List<Contact> contacts = [select Id, Name, Email, Phone from Contact where Id = :customerId limit 1];

        if (contacts.isEmpty()) {
            throw new AuraHandledException('No customer found for the entered Customer ID. Please enter a valid Contact ID.');
        }

        Contact con = contacts[0];

        List<ActivityWrapper> activities = new List<ActivityWrapper>();

        List<ActivityWrapper> websiteActivities = getMockWebsiteActivities(customerId);
        activities.addAll(websiteActivities);

        Integer engagementScore = calculateWebsiteScore(websiteActivities);
        List<Task> tasks = [Select Id, Subject, ActivityDate, Status, CreatedDate from Task where WhoId = :customerId order by ActivityDate desc nulls LAST, CreatedDate desc limit 5
        ];

        for (Task t : tasks) {
            ActivityWrapper activity = new ActivityWrapper();
            activity.key = t.Id;
            activity.source = 'Salesforce CRM';
            activity.type = 'Task';
            activity.subject = t.Subject;
            activity.activityDate = t.ActivityDate;
            activity.status = t.Status;
            activity.productCategory = null;
            activities.add(activity);

            engagementScore += calculateCrmActivityScore(t.Subject);
        }

        List<Event> events = [select Id, Subject, ActivityDate, CreatedDate from Event where WhoId = :customerId order BY ActivityDate desc nulls LAST, CreatedDate desc limit 5];

        for (Event e : events) {
            ActivityWrapper activity = new ActivityWrapper();
            activity.key = e.Id;
            activity.source = 'Salesforce CRM';
            activity.type = 'Event';
            activity.subject = e.Subject;
            activity.activityDate = e.ActivityDate;
            activity.status = 'Completed';
            activity.productCategory = null;
            activities.add(activity);

            engagementScore += calculateCrmActivityScore(e.Subject);
        }

        CustomerInsightWrapper result = new CustomerInsightWrapper();
        result.customerId = con.Id;
        result.name = con.Name;
        result.email = con.Email;
        result.phone = con.Phone;
        result.engagementScore = engagementScore;
        result.intentLevel = getIntentLevel(engagementScore);
        result.productInterest = getPrimaryProductInterest(websiteActivities);
        result.recentActivities = activities;

        return result;
    }

    @AuraEnabled
    public static ReccosWrapper getRecommendation(Integer engagementScore, String intentLevel, String productInterest) {
        if (engagementScore == null) {
            throw new AuraHandledException('Engagement score is required.');
        }

        ReccosWrapper result = new ReccosWrapper();

        if (intentLevel == 'High') {
            result.recommendation = 'Immediate follow-up call';
            result.reason =
                'Customer has high engagement and high purchase intent. They have shown interest in ' +
                productInterest +
                ', so the sales representative should follow up quickly with a personalized offer.';
        } else if (intentLevel == 'Medium') {
            result.recommendation = 'Send a personalized product email';
            result.reason =
                'Customer has moderate engagement and interest in ' +
                productInterest +
                '. An email can bring interest without being too aggressive.';
        } else {
            result.recommendation = 'Add customer to nurture campaign';
            result.reason =
                'Customer engagement is low. A campaign can help re-engage the customer over time.';
        }

        return result;
    }
    //method for mock activities to display 
    private static List<ActivityWrapper> getMockWebsiteActivities(String customerId) {
        List<ActivityWrapper> activities = new List<ActivityWrapper>();

        activities.add(createWebsiteActivity(
            'WEB-001',
            'Product View',
            'Viewed product: Book',
            Date.today().addDays(-1),
            'Book'
        ));

        activities.add(createWebsiteActivity(
            'WEB-002',
            'Page View',
            'Viewed pricing page',
            Date.today().addDays(-2),
            null
        ));

        activities.add(createWebsiteActivity(
            'WEB-003',
            'Product View',
            'Viewed product: Book',
            Date.today().addDays(-3),
            'Book'
        ));

        activities.add(createWebsiteActivity(
            'WEB-004',
            'Form Submission',
            'Submitted contact form',
            Date.today().addDays(-4),
            null
        ));

        return activities;
    }

    //method created so that data in wrapper doesnt get repeated instead we are declaring one fn with params
    private static ActivityWrapper createWebsiteActivity(
        String key,
        String type,
        String subject,
        Date activityDate,
        String productCategory
    ) {
        ActivityWrapper activity = new ActivityWrapper();
        activity.key = key;
        activity.source = 'Data Cloud Website Activity';
        activity.type = type;
        activity.subject = subject;
        activity.activityDate = activityDate;
        activity.status = 'Captured';
        activity.productCategory = productCategory;
        return activity;
    }
    //method for mock data insights engagement score
    private static Integer calculateWebsiteScore(List<ActivityWrapper> websiteActivities) {
        Integer score = 0;

        for (ActivityWrapper activity : websiteActivities) {
            if (activity.type == 'Product View') {
                score += 5;
            } else if (activity.type == 'Page View') {
                score += 1;
            } else if (activity.type == 'Form Submission') {
                score += 10;
            } else {
                score += 1;
            }
        }

        return score;
    }
    //method to get engagement score from crm activities like tasks and events
    private static Integer calculateCrmActivityScore(String subject) {
        if (String.isBlank(subject)) {
            return 1;
        }

        String value = subject.toLowerCase();

        if (value.contains('demo')) {
            return 10;
        }
        if (value.contains('meeting')) {
            return 8;
        }
        if (value.contains('call')) {
            return 5;
        }
        if (value.contains('email')) {
            return 3;
        }

        return 1;
    }
    //method to get the most interested product the customer has
    private static String getPrimaryProductInterest(List<ActivityWrapper> websiteActivities) {
        Map<String, Integer> productCounts = new Map<String, Integer>();

        for (ActivityWrapper activity : websiteActivities) {
            if (String.isNotBlank(activity.productCategory)) {
                Integer currentCount = productCounts.containsKey(activity.productCategory)? productCounts.get(activity.productCategory): 0;
                productCounts.put(activity.productCategory, currentCount + 1);
            }
        }

        String topProduct = 'Not Available';
        Integer topCount = 0;

        for (String product : productCounts.keySet()) {
            if (productCounts.get(product) > topCount) {
                topCount = productCounts.get(product);
                topProduct = product;
            }
        }

        return topProduct;
    }
    //method to get the intent level of customer
    private static String getIntentLevel(Integer score) {
        if (score >= 25) {
            return 'High';
        }
        if (score >= 10) {
            return 'Medium';
        }
        return 'Low';
    }

    
}
