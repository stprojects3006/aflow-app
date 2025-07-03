package org.springframework.samples.petclinic.service;

import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class FilterConfig {

	@Bean
	public FilterRegistrationBean<qFilter> loggingFilter() {
		FilterRegistrationBean<qFilter> registrationBean = new FilterRegistrationBean<>();

		registrationBean.setFilter(new qFilter());
		registrationBean.addUrlPatterns("/*");
		registrationBean.setOrder(1);

		return registrationBean;
	}

}
