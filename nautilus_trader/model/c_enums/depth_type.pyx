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

cdef class DepthTypeParser:

    @staticmethod
    cdef str to_str(int value):
        if value == 1:
            return "VOLUME"
        elif value == 2:
            return "EXPOSURE"
        else:
            raise ValueError(f"value was invalid, was {value}")

    @staticmethod
    cdef DepthType from_str(str value) except *:
        if value == "VOLUME":
            return DepthType.VOLUME
        elif value == "EXPOSURE":
            return DepthType.EXPOSURE
        else:
            raise ValueError(f"value was invalid, was {value}")

    @staticmethod
    def to_str_py(int value):
        return DepthTypeParser.to_str(value)

    @staticmethod
    def from_str_py(str value):
        return DepthTypeParser.from_str(value)
