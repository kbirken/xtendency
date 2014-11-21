/*******************************************************************************
 * Copyright (c) 2012 itemis AG (http://www.itemis.eu) and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *******************************************************************************/
package org.nanosite.xtendency.tracer.core.interpreter.test;

import java.io.IOException;
import java.io.Reader;
import java.io.StringReader;

import org.antlr.runtime.ANTLRStringStream;
import org.antlr.runtime.CommonToken;
import org.antlr.runtime.Token;
import org.eclipse.xtend.core.XtendRuntimeModule;
import org.eclipse.xtend.core.XtendStandaloneSetup;
import org.eclipse.xtend.core.parser.InternalFlexer;
import org.eclipse.xtend.core.parser.antlr.internal.FlexerFactory;
import org.eclipse.xtend.core.parser.antlr.internal.InternalXtendLexer;
import org.eclipse.xtend.core.validation.XtendConfigurableIssueCodes;
import org.eclipse.xtend.core.xtend.XtendFactory;
import org.eclipse.xtext.common.types.access.CachingClasspathTypeProviderFactory;
import org.eclipse.xtext.common.types.access.ClasspathTypeProviderFactory;
import org.eclipse.xtext.preferences.IPreferenceValuesProvider;
import org.eclipse.xtext.preferences.IPreferenceValuesProvider.SingletonPreferenceValuesProvider;
import org.eclipse.xtext.preferences.PreferenceKey;
import org.eclipse.xtext.util.IAcceptor;
import org.eclipse.xtext.validation.ConfigurableIssueCodesProvider;
import org.eclipse.xtext.validation.SeverityConverter;
import org.eclipse.xtext.xbase.validation.IssueCodes;
import org.nanosite.xtendency.tracer.core.IClassManager;
import org.nanosite.xtendency.tracer.core.StandaloneClassManager;

import com.google.common.io.CharStreams;
import com.google.inject.Binder;
import com.google.inject.Guice;
import com.google.inject.Injector;
import com.google.inject.Singleton;

/**
 * @author Sebastian Zarnekow - Initial contribution and API
 */
public class XtendencyTestSetup extends XtendStandaloneSetup {

	@Override
	public Injector createInjector() {
		return Guice.createInjector(new XtendRuntimeTestModule());
	}
	
	/**
	 * @author Sebastian Zarnekow - Initial contribution and API
	 */
	public static class XtendRuntimeTestModule extends XtendRuntimeModule {
		public void configureSomething(Binder binder){
//			StandaloneClassManager instance = new StandaloneClassManager();
//			binder.bind(IClassManager.class).toInstance(instance);
//			binder.bind(StandaloneClassManager.class).toInstance(instance);
			binder.bind(IClassManager.class).to(StandaloneClassManager.class);
			binder.bind(StandaloneClassManager.class).in(Singleton.class);
		}
		
		@Override
		public ClassLoader bindClassLoaderToInstance() {
			return XtendencyTestSetup.class.getClassLoader();
		}

		public XtendFactory bindFactory() {
			return XtendFactory.eINSTANCE;
		}

		public Class<? extends ClasspathTypeProviderFactory> bindClasspathTypeProviderFactory() {
			return CachingClasspathTypeProviderFactory.class;
		}

		public Class<? extends IPreferenceValuesProvider> bindIPreferenceValuesProvider() {
			return SingletonPreferenceValuesProvider.class;
		}

		@Override
		public Class<? extends ConfigurableIssueCodesProvider> bindConfigurableIssueCodesProvider() {
			return SuspiciousOverloadIsErrorInTests.class;
		}
//		
//		public Class<? extends FlexerFactory> bindFlexerFactory() {
//			return AssertingFlexerFactory.class;
//		}
	}
	
	public static class AssertingFlexerFactory extends FlexerFactory {
		
		@Override
		public InternalFlexer createFlexer(Reader reader) {
			try {
				final String lexMe = CharStreams.toString(reader);
				ANTLRStringStream antlrStream = new ANTLRStringStream(lexMe);
				final InternalXtendLexer antlrImplementation = new InternalXtendLexer(antlrStream);
				final InternalFlexer delegate = super.createFlexer(new StringReader(lexMe));
				InternalFlexer result = new InternalFlexer() {
					public int advance() throws IOException {
						int result = delegate.advance();
						CommonToken antlrToken = (CommonToken) antlrImplementation.nextToken();
						String text = getTokenText();
						if (antlrToken.getType() != result) {
							throw mismatch(lexMe, antlrToken, text);
						}
						if (result != Token.EOF && !antlrToken.getText().equals(text)) {
							throw mismatch(lexMe, antlrToken, text);
						}
						return result;
					}

					private IllegalStateException mismatch(final String lexMe, CommonToken antlrToken, String other) {
						return new IllegalStateException(
								"Token mismatch at offset " + antlrToken.getStartIndex() + "(" + other + " vs " + antlrToken.getText() + ") in: " + lexMe);
					}

					public int getTokenLength() {
						return delegate.getTokenLength();
					}
					
					public String getTokenText() {
						return delegate.getTokenText();
					}

					public void yyreset(Reader reader) {
						delegate.yyreset(reader);
					}
				};
				return result;
			} catch (IOException e) {
				throw new RuntimeException(e);
			}
		}
		
	}
	
	@Singleton
	public static class SuspiciousOverloadIsErrorInTests extends XtendConfigurableIssueCodes {
		@Override
		protected void initialize(IAcceptor<PreferenceKey> iAcceptor) {
			super.initialize(iAcceptor);
			iAcceptor.accept(create(IssueCodes.SUSPICIOUSLY_OVERLOADED_FEATURE, SeverityConverter.SEVERITY_ERROR));
		}
	}

}