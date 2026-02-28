package com.example.hellomodule.gateway;

import com.inductiveautomation.ignition.gateway.model.AbstractGatewayModuleHook;

public class HelloGatewayHook extends AbstractGatewayModuleHook {
    @Override
    public void setup(com.inductiveautomation.ignition.gateway.model.GatewayContext context) {
        context.getLogger().info("HelloModule setup complete");
    }

    @Override
    public void startup(com.inductiveautomation.ignition.gateway.model.GatewayContext context) {
        context.getLogger().info("HelloModule started");
    }

    @Override
    public void shutdown() {
        // No-op
    }
}
