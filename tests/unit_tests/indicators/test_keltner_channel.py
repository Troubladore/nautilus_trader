# -------------------------------------------------------------------------------------------------
#  Copyright (C) 2015-2021 Nautech Systems Pty Ltd. All rights reserved.
#  https://nautechsystems.io
#
#  Licensed under the GNU Lesser General Public License Version 3.0 (the "License");
#  You may not use this file except in compliance with the License.
#  You may obtain a copy of the License at https://www.gnu.org/licenses/lgpl-3.0.en.html
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
# -------------------------------------------------------------------------------------------------

import unittest

from nautilus_trader.indicators.average.moving_average import MovingAverageType
from nautilus_trader.indicators.keltner_channel import KeltnerChannel
from tests.test_kit.providers import TestInstrumentProvider
from tests.test_kit.stubs import TestStubs


AUDUSD_SIM = TestInstrumentProvider.default_fx_ccy("AUD/USD")


class KeltnerChannelTests(unittest.TestCase):
    def setUp(self):
        # Fixture Setup
        self.kc = KeltnerChannel(
            10, 2.5, MovingAverageType.EXPONENTIAL, MovingAverageType.SIMPLE
        )

    def test_name_returns_expected_string(self):
        # Arrange
        # Act
        # Assert
        self.assertEqual("KeltnerChannel", self.kc.name)

    def test_str_repr_returns_expected_string(self):
        # Arrange
        # Act
        # Assert
        self.assertEqual(
            "KeltnerChannel(10, 2.5, EXPONENTIAL, SIMPLE, True, 0.0)", str(self.kc)
        )
        self.assertEqual(
            "KeltnerChannel(10, 2.5, EXPONENTIAL, SIMPLE, True, 0.0)", repr(self.kc)
        )

    def test_period_returns_expected_value(self):
        # Arrange
        # Act
        # Assert
        self.assertEqual(10, self.kc.period)

    def test_k_multiple_returns_expected_value(self):
        # Arrange
        # Act
        # Assert
        self.assertEqual(2.5, self.kc.k_multiplier)

    def test_initialized_without_inputs_returns_false(self):
        # Arrange
        # Act
        # Assert
        self.assertEqual(False, self.kc.initialized)

    def test_initialized_with_required_inputs_returns_true(self):
        # Arrange
        self.kc.update_raw(1.00020, 1.00000, 1.00010)
        self.kc.update_raw(1.00020, 1.00000, 1.00010)
        self.kc.update_raw(1.00020, 1.00000, 1.00010)
        self.kc.update_raw(1.00020, 1.00000, 1.00010)
        self.kc.update_raw(1.00020, 1.00000, 1.00010)
        self.kc.update_raw(1.00020, 1.00000, 1.00010)
        self.kc.update_raw(1.00020, 1.00000, 1.00010)
        self.kc.update_raw(1.00020, 1.00000, 1.00010)
        self.kc.update_raw(1.00020, 1.00000, 1.00010)
        self.kc.update_raw(1.00020, 1.00000, 1.00010)

        # Act
        # Assert
        self.assertEqual(True, self.kc.initialized)

    def test_handle_bar_updates_indicator(self):
        # Arrange
        indicator = KeltnerChannel(
            10, 2.5, MovingAverageType.EXPONENTIAL, MovingAverageType.SIMPLE
        )

        bar = TestStubs.bar_5decimal()

        # Act
        indicator.handle_bar(bar)

        # Assert
        self.assertTrue(indicator.has_inputs)
        self.assertEqual(1.0000266666666666, indicator.middle)

    def test_value_with_one_input_returns_expected_value(self):
        # Arrange
        self.kc.update_raw(1.00020, 1.00000, 1.00010)

        # Act
        # Assert
        self.assertEqual(1.0006, self.kc.upper)
        self.assertEqual(1.0001, self.kc.middle)
        self.assertEqual(0.9996, self.kc.lower)

    def test_value_with_three_inputs_returns_expected_value(self):
        # Arrange
        self.kc.update_raw(1.00020, 1.00000, 1.00010)
        self.kc.update_raw(1.00030, 1.00010, 1.00020)
        self.kc.update_raw(1.00040, 1.00020, 1.00030)

        # Act
        # Assert
        self.assertEqual(1.0006512396694212, self.kc.upper)
        self.assertEqual(1.0001512396694212, self.kc.middle)
        self.assertEqual(0.9996512396694213, self.kc.lower)

    def test_reset_successfully_returns_indicator_to_fresh_state(self):
        # Arrange
        self.kc.update_raw(1.00020, 1.00000, 1.00010)
        self.kc.update_raw(1.00030, 1.00010, 1.00020)
        self.kc.update_raw(1.00040, 1.00020, 1.00030)

        # Act
        self.kc.reset()

        # Assert
        self.assertFalse(self.kc.initialized)
