/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *  http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */
package com.opensymphony.xwork2.validator;

import com.opensymphony.xwork2.Action;
import com.opensymphony.xwork2.ActionContext;
import com.opensymphony.xwork2.ActionInvocation;
import com.opensymphony.xwork2.ActionProxy;
import com.opensymphony.xwork2.AnnotatedTestBean;
import com.opensymphony.xwork2.FileManager;
import com.opensymphony.xwork2.FileManagerFactory;
import com.opensymphony.xwork2.SimpleAction;
import com.opensymphony.xwork2.SimpleAnnotationAction;
import com.opensymphony.xwork2.TextProviderFactory;
import com.opensymphony.xwork2.XWorkTestCase;
import com.opensymphony.xwork2.config.entities.ActionConfig;
import com.opensymphony.xwork2.test.AnnotationDataAware2;
import com.opensymphony.xwork2.test.AnnotationUser;
import com.opensymphony.xwork2.test.SimpleAnnotationAction2;
import com.opensymphony.xwork2.test.SimpleAnnotationAction3;
import com.opensymphony.xwork2.validator.validators.DateRangeFieldValidator;
import com.opensymphony.xwork2.validator.validators.DoubleRangeFieldValidator;
import com.opensymphony.xwork2.validator.validators.EmailValidator;
import com.opensymphony.xwork2.validator.validators.ExpressionValidator;
import com.opensymphony.xwork2.validator.validators.IntRangeFieldValidator;
import com.opensymphony.xwork2.validator.validators.RequiredFieldValidator;
import com.opensymphony.xwork2.validator.validators.RequiredStringValidator;
import com.opensymphony.xwork2.validator.validators.StringLengthFieldValidator;
import com.opensymphony.xwork2.validator.validators.URLValidator;
import org.easymock.EasyMock;

import java.util.List;



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
    private TextProviderFactory tpf;

    @Override protected void setUp() throws Exception {
        super.setUp();
        annotationActionValidatorManager = (AnnotationActionValidatorManager) container.getInstance(ActionValidatorManager.class);

        ActionConfig config = new ActionConfig.Builder("packageName", "name", "").build();
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

        tpf = container.getInstance(TextProviderFactory.class);
    }

    @Override protected void tearDown() throws Exception {
        annotationActionValidatorManager = null;
        super.tearDown();
    }

    public void testGetValidatorsForInterface() {
        List validatorList = annotationActionValidatorManager.getValidators(AnnotationDataAware2.class, alias);

        // 1 in interface hierarchy, 2 from parent interface (1 default + 1 context)
        assertEquals(3, validatorList.size());

        final FieldValidator dataValidator1 = (FieldValidator) validatorList.get(0);
        assertEquals("data", dataValidator1.getFieldName());
        assertTrue(dataValidator1 instanceof RequiredFieldValidator);

        final FieldValidator dataValidator2 = (FieldValidator) validatorList.get(1);
        assertEquals("data", dataValidator2.getFieldName());
        assertTrue(dataValidator2 instanceof RequiredStringValidator);

        final FieldValidator blingValidator = (FieldValidator) validatorList.get(2);
        assertEquals("bling", blingValidator.getFieldName());
        assertTrue(blingValidator instanceof RequiredStringValidator);
    }

}
