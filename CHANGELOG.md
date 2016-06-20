Shark Changelog
===============

##v2.0.2 - June 19, 2016
Updated the podspec, pushed a new version due to a problem merging a pull request

##v2.0.1 - June 18, 2016
JOIN: Added join tests & fixed bugs with join.
This turned up some faults when you wanted to Query C From A through a B join.  So, if you specifically specified the FQ field name it failed, because the ORM attemoted to prepent the self.class name.

Structure:
[Person]->[Deaprtment]->[Location]

Code example:
```objective-c
Person * p = [[[[[Person query]
                    joinTo:[Department class] leftParameter:@"department" targetParameter:@"Id"]
                    joinTo:[Location class] leftParameter:@"Department.location" targetParameter:@"Id"]
                     fetch]
               firstObject];
```


Fixed framework build output to include x86_64 in the available architectures

##v2.0.0 - June 16, 2016
Initial check in.  Replaces the DBAccess project from v1.6.13
