import json
import unittest

import utils


class UtilsTest(unittest.TestCase):
    def test_json_round_trip(self):
        appliance = {
            "sip": {"ipv4": 16777482},
            "vm_vni": 4321,
            "local_region_id": 100,
            "outbound_direction_lookup": "dst_mac",
            "trusted_vnis_list": [{"value": 100}],
        }
        encoded = json.dumps(appliance).encode()
        binary = utils.JsonStringToPbBinary(b"DASH_APPLIANCE_TABLE", encoded)
        decoded = utils.PbBinaryToJsonString(b"DASH_APPLIANCE_TABLE", binary)
        self.assertEqual(json.loads(decoded), appliance)


if __name__ == "__main__":
    unittest.main()
