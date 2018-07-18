//    MIT License
//
//    Copyright (c) 2010-2018 SharkSync
//
//    Permission is hereby granted, free of charge, to any person obtaining a copy
//    of this software and associated documentation files (the "Software"), to deal
//    in the Software without restriction, including without limitation the rights
//    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//    copies of the Software, and to permit persons to whom the Software is
//    furnished to do so, subject to the following conditions:
//
//    The above copyright notice and this permission notice shall be included in all
//    copies or substantial portions of the Software.
//
//    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//    SOFTWARE.

#import "SRKTransactionInfo.h"
#import "SRKEntity+Private.h"

@implementation SRKTransactionInfo

- (void)copyObjectValuesIntoRestorePoint:(SRKEntity*)object {
    
    self.originalFieldData = [NSMutableDictionary dictionaryWithDictionary:object.fieldData.copy];
    self.originalChangedValues = [NSMutableDictionary dictionaryWithDictionary:object.changedValues.copy];
    self.originalPk = object.reflectedPrimaryKeyValue;
    self.originalIsDirty = object.dirty;
    self.originalDirtyFields = [NSMutableDictionary dictionaryWithDictionary:object.dirtyFields.copy];
    self.originalEmbeddedEntities = [NSMutableDictionary dictionaryWithDictionary: object.embeddedEntities.copy];

}

- (void)restoreValuesIntoObject:(SRKEntity*)object {
    
    object.fieldData = self.originalFieldData;
    object.changedValues = self.originalChangedValues;
    [object setReflectedPrimaryKeyValue:self.originalPk];
    object.dirty = self.originalIsDirty;
    object.dirtyFields = self.originalDirtyFields;
    object.embeddedEntities = self.originalEmbeddedEntities;
    
}

@end
