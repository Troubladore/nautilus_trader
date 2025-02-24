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

from libc.stdint cimport int64_t

from nautilus_trader.model.identifiers cimport BracketOrderId
from nautilus_trader.model.order.base cimport Order
from nautilus_trader.model.order.limit cimport LimitOrder
from nautilus_trader.model.order.stop_market cimport StopMarketOrder


cdef class BracketOrder:
    cdef readonly BracketOrderId id
    """The bracket order identifier.\n\n:returns: `BracketOrderId`"""
    cdef readonly Order entry
    """The entry order.\n\n:returns: `Order`"""
    cdef readonly StopMarketOrder stop_loss
    """The stop-loss order.\n\n:returns: `StopMarketOrder`"""
    cdef readonly LimitOrder take_profit
    """The take-profit order.\n\n:returns: `LimitOrder`"""
    cdef readonly int64_t timestamp_ns
    """The Unix timestamp (nanos) of the bracket order.\n\n:returns: `int64`"""
