#include "utils.h"

#include <map>
#include <stdexcept>
#include <string>

#include <gtest/gtest.h>
#include <google/protobuf/descriptor.h>

namespace {

const std::map<std::string, std::string> kTableToTypeUrl = {
    {"DASH_ACL_GROUP_TABLE", "sonic/dash.acl_group.AclGroup"},
    {"DASH_ACL_IN_TABLE", "sonic/dash.acl_in.AclIn"},
    {"DASH_ACL_OUT_TABLE", "sonic/dash.acl_out.AclOut"},
    {"DASH_ACL_RULE_TABLE", "sonic/dash.acl_rule.AclRule"},
    {"DASH_APPLIANCE_TABLE", "sonic/dash.appliance.Appliance"},
    {"DASH_ENI_TABLE", "sonic/dash.eni.Eni"},
    {"DASH_ENI_ROUTE_TABLE", "sonic/dash.eni_route.EniRoute"},
    {"DASH_HA_SCOPE_TABLE", "sonic/dash.ha_scope.HaScope"},
    {"DASH_HA_SCOPE_CONFIG_TABLE", "sonic/dash.ha_scope_config.HaScopeConfig"},
    {"DASH_HA_SCOPE_STATE_TABLE", "sonic/dash.ha_scope_state.HaScopeState"},
    {"DASH_HA_SET_TABLE", "sonic/dash.ha_set.HaSet"},
    {"DASH_HA_SET_CONFIG_TABLE", "sonic/dash.ha_set_config.HaSetConfig"},
    {"DASH_HA_SET_STATE_TABLE", "sonic/dash.ha_set_state.HaSetState"},
    {"DASH_METER_TABLE", "sonic/dash.meter.Meter"},
    {"DASH_METER_POLICY_TABLE", "sonic/dash.meter_policy.MeterPolicy"},
    {"DASH_METER_RULE_TABLE", "sonic/dash.meter_rule.MeterRule"},
    {"DASH_OUTBOUND_PORT_MAP_TABLE", "sonic/dash.outbound_port_map.OutboundPortMap"},
    {"DASH_OUTBOUND_PORT_MAP_RANGE_TABLE", "sonic/dash.outbound_port_map_range.OutboundPortMapRange"},
    {"DASH_PA_VALIDATION_TABLE", "sonic/dash.pa_validation.PaValidation"},
    {"DASH_PREFIX_TAG_TABLE", "sonic/dash.prefix_tag.PrefixTag"},
    {"DASH_QOS_TABLE", "sonic/dash.qos.Qos"},
    {"DASH_ROUTE_TABLE", "sonic/dash.route.Route"},
    {"DASH_ROUTE_GROUP_TABLE", "sonic/dash.route_group.RouteGroup"},
    {"DASH_ROUTE_RULE_TABLE", "sonic/dash.route_rule.RouteRule"},
    {"DASH_ROUTE_TYPE_TABLE", "sonic/dash.route_type.RouteType"},
    {"DASH_ROUTING_APPLIANCE_TABLE", "sonic/dash.routing_appliance.RoutingAppliance"},
    {"DASH_TUNNEL_TABLE", "sonic/dash.tunnel.Tunnel"},
    {"DASH_VNET_TABLE", "sonic/dash.vnet.Vnet"},
    {"DASH_VNET_MAPPING_TABLE", "sonic/dash.vnet_mapping.VnetMapping"},
};

TEST(UtilsTest, ConvertsEveryTableNameAndResolvesEveryDescriptor) {
    for (const auto& entry : kTableToTypeUrl) {
        EXPECT_EQ(dash::TableNameToTypeUrl(entry.first), entry.second);

        std::string descriptor_name = entry.second.substr(std::string("sonic/").size());
        // These legacy protobuf package names predate the table-to-type URL
        // convention. Keep testing their actual descriptors without changing
        // the wire/API namespaces consumed by sonic-swss.
        if (entry.first == "DASH_METER_TABLE") {
            descriptor_name = "dash.meter_rule.Meter";
        } else if (entry.first == "DASH_PREFIX_TAG_TABLE") {
            descriptor_name = "dash.tag.PrefixTag";
        }
        EXPECT_NE(
            google::protobuf::DescriptorPool::generated_pool()
                ->FindMessageTypeByName(descriptor_name),
            nullptr)
            << "descriptor missing for " << descriptor_name;
    }
}

TEST(UtilsTest, RejectsInvalidInput) {
    EXPECT_THROW(dash::TableNameToTypeUrl("DASH_ROUTE"), std::runtime_error);
    EXPECT_THROW(
        dash::JsonStringToPbBinary("DASH_ROUTE_RULE_TABLE", "invalid json"),
        std::runtime_error);
}

}  // namespace
