/*
 * Copyright 2002-2006,2009 The Apache Software Foundation.
 * 
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *      http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package com.opensymphony.xwork2.validator;

import com.opensymphony.xwork2.*;
import com.opensymphony.xwork2.config.entities.ActionConfig;
import com.opensymphony.xwork2.test.AnnotationDataAware2;
import com.opensymphony.xwork2.test.AnnotationUser;
import com.opensymphony.xwork2.test.SimpleAnnotationAction2;
import com.opensymphony.xwork2.test.SimpleAnnotationAction3;
import com.opensymphony.xwork2.util.FileManager;
import com.opensymphony.xwork2.validator.validators.*;

import java.util.List;

import org.easymock.EasyMock;


/**
 * AnnotationActionValidatorManagerTest
 *
 * @author Rainer Hermanns
 * @author Jason Carreira
 * @author tm_jee ( tm_jee (at) yahoo.co.uk )
 *         Created Jun 9, 2003 11:03:01 AM
 */
public class AnnotationActionValidatorManagerTest extends XWorkTestCase {

    protected final String alias = "annotationValidationAlias";

    AnnotationActionValidatorManager annotationActionValidatorManager;

    @Override protected void setUp() throws Exception {
        super.setUp();
        annotationActionValidatorManager = (AnnotationActionValidatorManager) container.getInstance(ActionValidatorManager.class);

        ActionConfig config = new ActionConfig.Builder("", "name", "").build();
        ActionInvocation invocation = EasyMock.createNiceMock(ActionInvocation.class);
        ActionProxy proxy = EasyMock.createNiceMock(ActionProxy.class);

        EasyMock.expect(invocation.getProxy()).andReturn(proxy).anyTimes();
        EasyMock.expect(invocation.getAction()).andReturn(null).anyTimes();
        EasyMock.expect(invocation.invoke()).andReturn(Action.SUCCESS).anyTimes();
        EasyMock.expect(proxy.getMethod()).andReturn("execute").anyTimes();
        EasyMock.expect(proxy.getConfig()).andReturn(config).anyTimes();


        EasyMock.replay(invocation);
        EasyMock.replay(proxy);

        ActionContext.getContext().setActionInvocation(invocation);
    }

    @Override protected void tearDown() throws Exception {
        annotationActionValidatorManager = null;
        super.tearDown();
    }

    public void testSkipUserMarkerActionLevelShortCircuit() {
        // get validators
        List validatorList = annotationActionValidatorManager.getValidators(AnnotationUser.class, null);
        assertEquals(10, validatorList.size());

        try {
            AnnotationUser user = new AnnotationUser();
            user.setName("Mark");
            user.setEmail("bad_email");
            user.setEmail2("bad_email");

            ValidatorContext context = new GenericValidatorContext(user);
            annotationActionValidatorManager.validate(user, null, context);
            assertTrue(context.hasFieldErrors());

            // check field errors
            List<String> l = context.getFieldErrors().get("email");
            assertNotNull(l);
            assertEquals(1, l.size());
            assertEquals("Not a valid e-mail.", l.get(0));
            l = context.getFieldErrors().get("email2");
            assertNotNull(l);
            assertEquals(2, l.size());
            assertEquals("Not a valid e-mail2.", l.get(0));
            assertEquals("Email2 not from the right company.", l.get(1));

            // check action errors
            assertTrue(context.hasActionErrors());
            l = (List<String>) context.getActionErrors();
            assertNotNull(l);
            assertEquals(2, l.size()); // both expression test failed see AnnotationUser-validation.xml
            assertEquals("Email does not start with mark", l.get(0));
        } catch (ValidationException ex) {
            ex.printStackTrace();
            fail("Validation error: " + ex.getMessage());
        }
    }
}
